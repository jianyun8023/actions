import datetime
import os
from uuid import uuid4

from app.config import DEFAULT_APP_ID, USER_ID
from app.database import Base, SessionLocal, engine
from app.mcp_server import setup_mcp_server
from app.models import App, User
from app.routers import apps_router, backup_router, config_router, memories_router, stats_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi_pagination import add_pagination
from sqlalchemy import text

app = FastAPI(
    title="OpenMemory API"
    # redirect_slashes=True (默认) - 自动将 /path 重定向到 /path/
)


# ============================================
# Health Check Endpoints
# ============================================
@app.get("/health", tags=["health"])
async def health_check():
    """
    Liveness probe - 检查服务是否存活
    用于 Kubernetes liveness probe 或 Docker HEALTHCHECK
    """
    return {"status": "healthy"}


@app.get("/health/ready", tags=["health"])
async def readiness_check():
    """
    Readiness probe - 检查服务是否就绪（包括依赖服务）
    用于 Kubernetes readiness probe
    """
    checks = {
        "database": False,
        "qdrant": False,
    }
    
    # 检查数据库连接
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        checks["database"] = True
    except Exception as e:
        checks["database_error"] = str(e)
    
    # 检查 Qdrant 连接（可选）
    qdrant_host = os.getenv("QDRANT_HOST")
    if qdrant_host:
        try:
            import urllib.request
            qdrant_port = os.getenv("QDRANT_PORT", "6333")
            url = f"http://{qdrant_host}:{qdrant_port}/healthz"
            with urllib.request.urlopen(url, timeout=5) as response:
                if response.status == 200:
                    checks["qdrant"] = True
        except Exception as e:
            checks["qdrant_error"] = str(e)
    else:
        checks["qdrant"] = "not_configured"
    
    # 判断整体状态
    is_ready = checks["database"] is True
    status_code = 200 if is_ready else 503
    
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ready" if is_ready else "not_ready",
            "checks": checks
        }
    )


@app.get("/health/live", tags=["health"])
async def liveness_check():
    """
    简化的存活检查（别名）
    """
    return {"status": "alive"}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,  # 使用 * 时不能启用 credentials
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],  # 允许前端访问响应头
)

# Create all tables
Base.metadata.create_all(bind=engine)

# Check for USER_ID and create default user if needed
def create_default_user():
    db = SessionLocal()
    try:
        # Check if user exists
        user = db.query(User).filter(User.user_id == USER_ID).first()
        if not user:
            # Create default user
            user = User(
                id=uuid4(),
                user_id=USER_ID,
                name="Default User",
                created_at=datetime.datetime.now(datetime.UTC)
            )
            db.add(user)
            db.commit()
    finally:
        db.close()


def create_default_app():
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.user_id == USER_ID).first()
        if not user:
            return

        # Check if app already exists
        existing_app = db.query(App).filter(
            App.name == DEFAULT_APP_ID,
            App.owner_id == user.id
        ).first()

        if existing_app:
            return

        app = App(
            id=uuid4(),
            name=DEFAULT_APP_ID,
            owner_id=user.id,
            created_at=datetime.datetime.now(datetime.UTC),
            updated_at=datetime.datetime.now(datetime.UTC),
        )
        db.add(app)
        db.commit()
    finally:
        db.close()

# Create default user on startup
create_default_user()
create_default_app()

# Setup MCP server
setup_mcp_server(app)

# Include routers
app.include_router(memories_router)
app.include_router(apps_router)
app.include_router(stats_router)
app.include_router(config_router)
app.include_router(backup_router)

# Add pagination support
add_pagination(app)
