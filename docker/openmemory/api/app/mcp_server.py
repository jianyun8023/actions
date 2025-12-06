"""
MCP Server for OpenMemory with resilient memory client handling.

This module implements an MCP (Model Context Protocol) server that provides
memory operations for OpenMemory. The memory client is initialized lazily
to prevent server crashes when external dependencies (like Ollama) are
unavailable. If the memory client cannot be initialized, the server will
continue running with limited functionality and appropriate error messages.

Key features:
- Lazy memory client initialization
- Graceful error handling for unavailable dependencies
- Fallback to database-only mode when vector store is unavailable
- Proper logging for debugging connection issues
- Environment variable parsing for API keys
"""

import asyncio
import concurrent.futures
import contextvars
import datetime
import json
import logging
import os
import time
import uuid

from app.database import SessionLocal
from app.models import Memory, MemoryAccessLog, MemoryState, MemoryStatusHistory
from app.utils.db import get_user_and_app
from app.utils.memory import get_memory_client
from app.utils.permissions import check_memory_access_permissions
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.routing import APIRouter
from mcp.server.fastmcp import FastMCP
from mcp.server.sse import SseServerTransport

# Load environment variables
load_dotenv()

# Initialize MCP
mcp = FastMCP("mem0-mcp-server")

# Don't initialize memory client at import time - do it lazily when needed
def get_memory_client_safe():
    """Get memory client with error handling. Returns None if client cannot be initialized."""
    try:
        return get_memory_client()
    except Exception as e:
        logging.warning(f"Failed to get memory client: {e}")
        return None

# Context variables for user_id and client_name
user_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("user_id")
client_name_var: contextvars.ContextVar[str] = contextvars.ContextVar("client_name")

# Create a router for MCP endpoints
mcp_router = APIRouter(prefix="/mcp")

# Initialize SSE transport
sse = SseServerTransport("/mcp/messages/")

# Timeout for memory operations (in seconds)
MEMORY_OPERATION_TIMEOUT = int(os.environ.get("MEMORY_OPERATION_TIMEOUT", "120"))

# Maximum input text length (characters) - prevents LLM context overflow
# Default 8000 chars ≈ 2000-4000 tokens depending on language
MAX_INPUT_TEXT_LENGTH = int(os.environ.get("MAX_INPUT_TEXT_LENGTH", "8000"))

# Whether to truncate or reject long inputs
TRUNCATE_LONG_INPUT = os.environ.get("TRUNCATE_LONG_INPUT", "true").lower() in ("true", "1", "yes")


def _truncate_text(text: str, max_length: int) -> str:
    """Truncate text to max_length, adding ellipsis if truncated."""
    if len(text) <= max_length:
        return text
    # Keep first 70% and last 20% to preserve both context and ending
    first_part = int(max_length * 0.7)
    last_part = int(max_length * 0.2)
    return text[:first_part] + "\n...[truncated]...\n" + text[-last_part:]


def _add_memory_sync(memory_client, text: str, uid: str, client_name: str):
    """Synchronous wrapper for memory_client.add() to run in thread pool."""
    return memory_client.add(
        text,
        user_id=uid,
        metadata={
            "source_app": "openmemory",
            "mcp_client": client_name,
        }
    )


@mcp.tool(description="Add a new memory. This method is called everytime the user informs anything about themselves, their preferences, or anything that has any relevant information which can be useful in the future conversation. This can also be called when the user asks you to remember something.")
async def add_memories(text: str) -> str:
    uid = user_id_var.get(None)
    client_name = client_name_var.get(None)

    if not uid:
        return "Error: user_id not provided"
    if not client_name:
        return "Error: client_name not provided"

    start_time = time.time()
    original_length = len(text)
    logging.info(f"[MCP] add_memories started for user={uid}, client={client_name}, text_length={original_length}")

    # Check input text length
    if original_length > MAX_INPUT_TEXT_LENGTH:
        if TRUNCATE_LONG_INPUT:
            text = _truncate_text(text, MAX_INPUT_TEXT_LENGTH)
            logging.warning(f"[MCP] Input text truncated from {original_length} to {len(text)} chars (max: {MAX_INPUT_TEXT_LENGTH})")
        else:
            logging.error(f"[MCP] Input text too long: {original_length} chars (max: {MAX_INPUT_TEXT_LENGTH})")
            return f"Error: Input text too long ({original_length} chars). Maximum allowed: {MAX_INPUT_TEXT_LENGTH} chars. Set TRUNCATE_LONG_INPUT=true to auto-truncate."

    # Get memory client safely
    logging.info("[MCP] Getting memory client...")
    memory_client = get_memory_client_safe()
    if not memory_client:
        return "Error: Memory system is currently unavailable. Please try again later."
    logging.info(f"[MCP] Memory client ready (elapsed: {time.time() - start_time:.2f}s)")

    try:
        db = SessionLocal()
        try:
            # Get or create user and app
            user, app = get_user_and_app(db, user_id=uid, app_id=client_name)

            # Check if app is active
            if not app.is_active:
                return f"Error: App {app.name} is currently paused on OpenMemory. Cannot create new memories."

            # Run memory_client.add() with timeout using thread pool
            logging.info(f"[MCP] Calling memory_client.add() with timeout={MEMORY_OPERATION_TIMEOUT}s...")
            loop = asyncio.get_event_loop()
            with concurrent.futures.ThreadPoolExecutor() as executor:
                try:
                    response = await asyncio.wait_for(
                        loop.run_in_executor(
                            executor,
                            _add_memory_sync,
                            memory_client,
                            text,
                            uid,
                            client_name
                        ),
                        timeout=MEMORY_OPERATION_TIMEOUT
                    )
                except asyncio.TimeoutError:
                    elapsed = time.time() - start_time
                    logging.error(f"[MCP] memory_client.add() timed out after {elapsed:.2f}s")
                    return f"Error: Memory operation timed out after {MEMORY_OPERATION_TIMEOUT}s. The LLM or vector store may be slow or unavailable."
            
            logging.info(f"[MCP] memory_client.add() completed (elapsed: {time.time() - start_time:.2f}s)")

            # Log the raw response for debugging
            logging.debug(f"[MCP] Raw response from memory_client.add(): {response}")

            # Process the response and update database
            if isinstance(response, dict) and 'results' in response:
                results = response['results']
                logging.info(f"[MCP] Processing {len(results)} results from memory_client")
                
                for idx, result in enumerate(results):
                    event_type = result.get('event', 'UNKNOWN')
                    memory_content = result.get('memory', '')[:100]  # First 100 chars
                    logging.info(f"[MCP] Result {idx+1}: event={event_type}, memory_preview='{memory_content}...'")
                    
                    memory_id = uuid.UUID(result['id'])
                    memory = db.query(Memory).filter(Memory.id == memory_id).first()

                    if result['event'] == 'ADD':
                        if not memory:
                            logging.info(f"[MCP] Creating new memory: id={memory_id}")
                            memory = Memory(
                                id=memory_id,
                                user_id=user.id,
                                app_id=app.id,
                                content=result['memory'],
                                state=MemoryState.active
                            )
                            db.add(memory)
                        else:
                            logging.info(f"[MCP] Updating existing memory: id={memory_id}")
                            memory.state = MemoryState.active
                            memory.content = result['memory']

                        # Create history entry
                        history = MemoryStatusHistory(
                            memory_id=memory_id,
                            changed_by=user.id,
                            old_state=MemoryState.deleted if memory else None,
                            new_state=MemoryState.active
                        )
                        db.add(history)

                    elif result['event'] == 'DELETE':
                        if memory:
                            logging.info(f"[MCP] Deleting memory: id={memory_id}")
                            memory.state = MemoryState.deleted
                            memory.deleted_at = datetime.datetime.now(datetime.UTC)
                            # Create history entry
                            history = MemoryStatusHistory(
                                memory_id=memory_id,
                                changed_by=user.id,
                                old_state=MemoryState.active,
                                new_state=MemoryState.deleted
                            )
                            db.add(history)
                    
                    elif result['event'] == 'UPDATE':
                        if memory:
                            logging.info(f"[MCP] Memory updated by mem0: id={memory_id}")
                    
                    elif result['event'] == 'NOOP':
                        logging.info(f"[MCP] No operation needed (duplicate or unchanged): id={memory_id}")

                db.commit()
                logging.info(f"[MCP] Database commit successful, {len(results)} memories processed")
            else:
                logging.warning(f"[MCP] Unexpected response format: {type(response)}, response={str(response)[:200]}")

            total_elapsed = time.time() - start_time
            logging.info(f"[MCP] add_memories completed successfully (total elapsed: {total_elapsed:.2f}s)")
            return json.dumps(response)
        finally:
            db.close()
    except Exception as e:
        logging.exception(f"Error adding to memory: {e}")
        return f"Error adding to memory: {e}"


@mcp.tool(description="Search through stored memories. This method is called EVERYTIME the user asks anything.")
async def search_memory(query: str) -> str:
    import time
    start_time = time.time()
    
    uid = user_id_var.get(None)
    client_name = client_name_var.get(None)
    logging.info(f"[MCP] search_memory started: user={uid}, client={client_name}, query_length={len(query)}")
    logging.debug(f"[MCP] search_memory query: '{query[:200]}...'")
    
    if not uid:
        logging.warning("[MCP] search_memory: user_id not provided")
        return "Error: user_id not provided"
    if not client_name:
        logging.warning("[MCP] search_memory: client_name not provided")
        return "Error: client_name not provided"

    # Get memory client safely
    memory_client = get_memory_client_safe()
    if not memory_client:
        logging.error("[MCP] search_memory: Memory client unavailable")
        return "Error: Memory system is currently unavailable. Please try again later."

    try:
        db = SessionLocal()
        try:
            # Get or create user and app
            user, app = get_user_and_app(db, user_id=uid, app_id=client_name)
            logging.debug(f"[MCP] search_memory: user.id={user.id}, app.id={app.id}")

            # Get accessible memory IDs based on ACL
            user_memories = db.query(Memory).filter(Memory.user_id == user.id).all()
            accessible_memory_ids = [memory.id for memory in user_memories if check_memory_access_permissions(db, memory, app.id)]
            logging.info(f"[MCP] search_memory: {len(user_memories)} total memories, {len(accessible_memory_ids)} accessible")

            filters = {
                "user_id": uid
            }

            embed_start = time.time()
            embeddings = memory_client.embedding_model.embed(query, "search")
            logging.debug(f"[MCP] search_memory: embedding took {time.time() - embed_start:.2f}s")

            search_start = time.time()
            hits = memory_client.vector_store.search(
                query=query, 
                vectors=embeddings, 
                limit=10, 
                filters=filters,
            )
            logging.debug(f"[MCP] search_memory: vector search took {time.time() - search_start:.2f}s, got {len(hits)} hits")

            allowed = set(str(mid) for mid in accessible_memory_ids) if accessible_memory_ids else None

            results = []
            for h in hits:
                # All vector db search functions return OutputData class
                id, score, payload = h.id, h.score, h.payload
                if allowed and h.id is None or h.id not in allowed: 
                    logging.debug(f"[MCP] search_memory: skipping hit id={id} (not in allowed set)")
                    continue
                
                results.append({
                    "id": id, 
                    "memory": payload.get("data"), 
                    "hash": payload.get("hash"),
                    "created_at": payload.get("created_at"), 
                    "updated_at": payload.get("updated_at"), 
                    "score": score,
                })

            logging.info(f"[MCP] search_memory: {len(results)} results after ACL filtering")
            
            for r in results: 
                if r.get("id"): 
                    access_log = MemoryAccessLog(
                        memory_id=uuid.UUID(r["id"]),
                        app_id=app.id,
                        access_type="search",
                        metadata_={
                            "query": query,
                            "score": r.get("score"),
                            "hash": r.get("hash"),
                        },
                    )
                    db.add(access_log)
            db.commit()

            elapsed = time.time() - start_time
            logging.info(f"[MCP] search_memory completed: {len(results)} results in {elapsed:.2f}s")
            
            # Log top results for debugging
            for i, r in enumerate(results[:3]):
                memory_preview = (r.get("memory") or "")[:80]
                logging.debug(f"[MCP] search_memory result {i+1}: score={r.get('score'):.4f}, memory='{memory_preview}...'")

            return json.dumps({"results": results}, indent=2)
        finally:
            db.close()
    except Exception as e:
        elapsed = time.time() - start_time
        logging.exception(f"[MCP] search_memory error after {elapsed:.2f}s: {e}")
        return f"Error searching memory: {e}"


@mcp.tool(description="List all memories in the user's memory")
async def list_memories() -> str:
    import time
    start_time = time.time()
    
    uid = user_id_var.get(None)
    client_name = client_name_var.get(None)
    logging.info(f"[MCP] list_memories started: user={uid}, client={client_name}")
    
    if not uid:
        logging.warning("[MCP] list_memories: user_id not provided")
        return "Error: user_id not provided"
    if not client_name:
        logging.warning("[MCP] list_memories: client_name not provided")
        return "Error: client_name not provided"

    # Get memory client safely
    memory_client = get_memory_client_safe()
    if not memory_client:
        logging.error("[MCP] list_memories: Memory client unavailable")
        return "Error: Memory system is currently unavailable. Please try again later."

    try:
        db = SessionLocal()
        try:
            # Get or create user and app
            user, app = get_user_and_app(db, user_id=uid, app_id=client_name)
            logging.debug(f"[MCP] list_memories: user.id={user.id}, app.id={app.id}")

            # Get all memories
            logging.debug("[MCP] list_memories: fetching all memories from vector store")
            memories = memory_client.get_all(user_id=uid)
            filtered_memories = []

            # Filter memories based on permissions
            user_memories = db.query(Memory).filter(Memory.user_id == user.id).all()
            accessible_memory_ids = [memory.id for memory in user_memories if check_memory_access_permissions(db, memory, app.id)]
            logging.info(f"[MCP] list_memories: {len(user_memories)} total, {len(accessible_memory_ids)} accessible")
            
            if isinstance(memories, dict) and 'results' in memories:
                logging.debug(f"[MCP] list_memories: got {len(memories['results'])} memories from vector store")
                for memory_data in memories['results']:
                    if 'id' in memory_data:
                        memory_id = uuid.UUID(memory_data['id'])
                        if memory_id in accessible_memory_ids:
                            # Create access log entry
                            access_log = MemoryAccessLog(
                                memory_id=memory_id,
                                app_id=app.id,
                                access_type="list",
                                metadata_={
                                    "hash": memory_data.get('hash')
                                }
                            )
                            db.add(access_log)
                            filtered_memories.append(memory_data)
                db.commit()
            else:
                mem_count = len(memories) if memories else 0
                logging.debug(f"[MCP] list_memories: got {mem_count} memories (non-dict format)")
                for memory in memories:
                    memory_id = uuid.UUID(memory['id'])
                    memory_obj = db.query(Memory).filter(Memory.id == memory_id).first()
                    if memory_obj and check_memory_access_permissions(db, memory_obj, app.id):
                        # Create access log entry
                        access_log = MemoryAccessLog(
                            memory_id=memory_id,
                            app_id=app.id,
                            access_type="list",
                            metadata_={
                                "hash": memory.get('hash')
                            }
                        )
                        db.add(access_log)
                        filtered_memories.append(memory)
                db.commit()
            
            elapsed = time.time() - start_time
            logging.info(f"[MCP] list_memories completed: {len(filtered_memories)} memories in {elapsed:.2f}s")
            return json.dumps(filtered_memories, indent=2)
        finally:
            db.close()
    except Exception as e:
        elapsed = time.time() - start_time
        logging.exception(f"[MCP] list_memories error after {elapsed:.2f}s: {e}")
        return f"Error getting memories: {e}"


@mcp.tool(description="Delete specific memories by their IDs")
async def delete_memories(memory_ids: list[str]) -> str:
    import time
    start_time = time.time()
    
    uid = user_id_var.get(None)
    client_name = client_name_var.get(None)
    logging.info(f"[MCP] delete_memories started: user={uid}, client={client_name}, count={len(memory_ids)}")
    logging.debug(f"[MCP] delete_memories: IDs to delete: {memory_ids}")
    
    if not uid:
        logging.warning("[MCP] delete_memories: user_id not provided")
        return "Error: user_id not provided"
    if not client_name:
        logging.warning("[MCP] delete_memories: client_name not provided")
        return "Error: client_name not provided"

    # Get memory client safely
    memory_client = get_memory_client_safe()
    if not memory_client:
        logging.error("[MCP] delete_memories: Memory client unavailable")
        return "Error: Memory system is currently unavailable. Please try again later."

    try:
        db = SessionLocal()
        try:
            # Get or create user and app
            user, app = get_user_and_app(db, user_id=uid, app_id=client_name)
            logging.debug(f"[MCP] delete_memories: user.id={user.id}, app.id={app.id}")

            # Convert string IDs to UUIDs and filter accessible ones
            requested_ids = [uuid.UUID(mid) for mid in memory_ids]
            user_memories = db.query(Memory).filter(Memory.user_id == user.id).all()
            accessible_memory_ids = [memory.id for memory in user_memories if check_memory_access_permissions(db, memory, app.id)]
            logging.info(f"[MCP] delete_memories: {len(requested_ids)} requested, {len(accessible_memory_ids)} accessible")

            # Only delete memories that are both requested and accessible
            ids_to_delete = [mid for mid in requested_ids if mid in accessible_memory_ids]
            logging.info(f"[MCP] delete_memories: {len(ids_to_delete)} will be deleted")

            if not ids_to_delete:
                logging.warning("[MCP] delete_memories: No accessible memories found")
                return "Error: No accessible memories found with provided IDs"

            # Delete from vector store
            deleted_count = 0
            failed_count = 0
            for memory_id in ids_to_delete:
                try:
                    memory_client.delete(str(memory_id))
                    deleted_count += 1
                    logging.debug(f"[MCP] delete_memories: deleted {memory_id} from vector store")
                except Exception as delete_error:
                    failed_count += 1
                    logging.warning(f"[MCP] delete_memories: failed to delete {memory_id} from vector store: {delete_error}")

            # Update each memory's state and create history entries
            now = datetime.datetime.now(datetime.UTC)
            for memory_id in ids_to_delete:
                memory = db.query(Memory).filter(Memory.id == memory_id).first()
                if memory:
                    # Update memory state
                    memory.state = MemoryState.deleted
                    memory.deleted_at = now

                    # Create history entry
                    history = MemoryStatusHistory(
                        memory_id=memory_id,
                        changed_by=user.id,
                        old_state=MemoryState.active,
                        new_state=MemoryState.deleted
                    )
                    db.add(history)

                    # Create access log entry
                    access_log = MemoryAccessLog(
                        memory_id=memory_id,
                        app_id=app.id,
                        access_type="delete",
                        metadata_={"operation": "delete_by_id"}
                    )
                    db.add(access_log)

            db.commit()
            elapsed = time.time() - start_time
            logging.info(f"[MCP] delete_memories completed: {len(ids_to_delete)} deleted, {failed_count} failed in {elapsed:.2f}s")
            return f"Successfully deleted {len(ids_to_delete)} memories"
        finally:
            db.close()
    except Exception as e:
        elapsed = time.time() - start_time
        logging.exception(f"[MCP] delete_memories error after {elapsed:.2f}s: {e}")
        return f"Error deleting memories: {e}"


@mcp.tool(description="Delete all memories in the user's memory")
async def delete_all_memories() -> str:
    import time
    start_time = time.time()
    
    uid = user_id_var.get(None)
    client_name = client_name_var.get(None)
    logging.info(f"[MCP] delete_all_memories started: user={uid}, client={client_name}")
    
    if not uid:
        logging.warning("[MCP] delete_all_memories: user_id not provided")
        return "Error: user_id not provided"
    if not client_name:
        logging.warning("[MCP] delete_all_memories: client_name not provided")
        return "Error: client_name not provided"

    # Get memory client safely
    memory_client = get_memory_client_safe()
    if not memory_client:
        logging.error("[MCP] delete_all_memories: Memory client unavailable")
        return "Error: Memory system is currently unavailable. Please try again later."

    try:
        db = SessionLocal()
        try:
            # Get or create user and app
            user, app = get_user_and_app(db, user_id=uid, app_id=client_name)

            user_memories = db.query(Memory).filter(Memory.user_id == user.id).all()
            accessible_memory_ids = [memory.id for memory in user_memories if check_memory_access_permissions(db, memory, app.id)]

            # delete the accessible memories only
            for memory_id in accessible_memory_ids:
                try:
                    memory_client.delete(str(memory_id))
                except Exception as delete_error:
                    logging.warning(f"Failed to delete memory {memory_id} from vector store: {delete_error}")

            # Update each memory's state and create history entries
            now = datetime.datetime.now(datetime.UTC)
            for memory_id in accessible_memory_ids:
                memory = db.query(Memory).filter(Memory.id == memory_id).first()
                # Update memory state
                memory.state = MemoryState.deleted
                memory.deleted_at = now

                # Create history entry
                history = MemoryStatusHistory(
                    memory_id=memory_id,
                    changed_by=user.id,
                    old_state=MemoryState.active,
                    new_state=MemoryState.deleted
                )
                db.add(history)

                # Create access log entry
                access_log = MemoryAccessLog(
                    memory_id=memory_id,
                    app_id=app.id,
                    access_type="delete_all",
                    metadata_={"operation": "bulk_delete"}
                )
                db.add(access_log)

            db.commit()
            return "Successfully deleted all memories"
        finally:
            db.close()
    except Exception as e:
        logging.exception(f"Error deleting memories: {e}")
        return f"Error deleting memories: {e}"


@mcp_router.get("/{client_name}/sse/{user_id}")
async def handle_sse(request: Request):
    """Handle SSE connections for a specific user and client"""
    # Extract user_id and client_name from path parameters
    uid = request.path_params.get("user_id")
    user_token = user_id_var.set(uid or "")
    client_name = request.path_params.get("client_name")
    client_token = client_name_var.set(client_name or "")

    logging.info(f"[MCP-SSE] New SSE connection: client={client_name}, user={uid}")

    try:
        # Handle SSE connection
        async with sse.connect_sse(
            request.scope,
            request.receive,
            request._send,
        ) as (read_stream, write_stream):
            logging.info(f"[MCP-SSE] SSE session established for client={client_name}, user={uid}")
            await mcp._mcp_server.run(
                read_stream,
                write_stream,
                mcp._mcp_server.create_initialization_options(),
            )
    except Exception as e:
        logging.error(f"[MCP-SSE] SSE connection error for client={client_name}, user={uid}: {e}")
        raise
    finally:
        # Clean up context variables
        logging.info(f"[MCP-SSE] SSE connection closed for client={client_name}, user={uid}")
        user_id_var.reset(user_token)
        client_name_var.reset(client_token)


@mcp_router.post("/messages/")
async def handle_messages_post(request: Request):
    return await _handle_post_message_impl(request)


@mcp_router.post("/{client_name}/sse/{user_id}/messages/")
async def handle_sse_messages_post(request: Request):
    return await _handle_post_message_impl(request)


async def _handle_post_message_impl(request: Request):
    """Handle POST messages for SSE"""
    from fastapi.responses import JSONResponse
    
    session_id = request.query_params.get("session_id", "unknown")
    logging.info(f"[MCP-POST] Processing message for session={session_id}")
    
    try:
        body = await request.body()
        logging.debug(f"[MCP-POST] Received message for session={session_id}, body_length={len(body)}")

        # Create a simple receive function that returns the body
        async def receive():
            return {"type": "http.request", "body": body, "more_body": False}

        # Track response
        response_sent = []
        async def send(message):
            response_sent.append(message)
            return {}

        # Call handle_post_message with the correct arguments
        await sse.handle_post_message(request.scope, receive, send)

        # Return a success response
        logging.info(f"[MCP-POST] Message processed successfully for session={session_id}")
        return {"status": "ok"}
        
    except KeyError as e:
        # Session not found during processing
        error_msg = str(e)
        logging.warning(f"[MCP-POST] Session not found: {session_id}, error: {error_msg}")
        return JSONResponse(
            status_code=410,  # Gone - session no longer exists
            content={
                "status": "error",
                "error": "session_not_found",
                "message": f"Session '{session_id}' was not found or has expired. Please reconnect to the MCP server.",
                "session_id": session_id,
                "hint": "Disconnect and reconnect the MCP client to establish a new session."
            }
        )
    except Exception as e:
        error_msg = str(e)
        # Check if this is a session-related error
        if "session" in error_msg.lower() or "not found" in error_msg.lower():
            logging.warning(f"[MCP-POST] Session error for {session_id}: {error_msg}")
            return JSONResponse(
                status_code=410,
                content={
                    "status": "error",
                    "error": "session_expired",
                    "message": f"Session '{session_id}' has expired or is invalid. Please reconnect.",
                    "session_id": session_id,
                    "hint": "Disconnect and reconnect the MCP client to establish a new session."
                }
            )
        
        logging.error(f"[MCP-POST] Error handling message for session={session_id}: {error_msg}")
        return JSONResponse(
            status_code=500,
            content={
                "status": "error",
                "error": "internal_error",
                "message": error_msg,
                "session_id": session_id
            }
        )

def setup_mcp_server(app: FastAPI):
    """Setup MCP server with the FastAPI application"""
    mcp._mcp_server.name = "mem0-mcp-server"

    # Include MCP router in the FastAPI app
    app.include_router(mcp_router)
