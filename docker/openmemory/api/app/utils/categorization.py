import logging
import os
from typing import List, Optional

from app.utils.prompts import MEMORY_CATEGORIZATION_PROMPT
from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel
from tenacity import retry, stop_after_attempt, wait_exponential

load_dotenv()


class MemoryCategories(BaseModel):
    categories: List[str]


def _get_llm_config() -> tuple[str, str, Optional[str]]:
    """
    从配置中获取 LLM 设置，优先级：
    1. 数据库配置
    2. 环境变量
    3. 默认值
    """
    try:
        # 尝试从数据库读取配置
        from app.database import SessionLocal
        from app.models import Config as ConfigModel
        
        db = SessionLocal()
        try:
            config = db.query(ConfigModel).filter(ConfigModel.key == "main").first()
            if config and config.value:
                mem0_config = config.value.get("mem0", {})
                llm_config = mem0_config.get("llm", {}).get("config", {})
                
                model = llm_config.get("model")
                api_key = llm_config.get("api_key")
                base_url = llm_config.get("base_url")
                
                # 解析 env: 前缀
                if api_key and api_key.startswith("env:"):
                    api_key = os.getenv(api_key[4:])
                
                if model and api_key:
                    return model, api_key, base_url
        finally:
            db.close()
    except Exception as e:
        logging.debug(f"Failed to load config from database: {e}")
    
    # 回退到环境变量
    model = os.getenv("LLM_MODEL", "gpt-4o-mini")
    api_key = os.getenv("OPENAI_API_KEY")
    base_url = os.getenv("OPENAI_BASE_URL")
    
    return model, api_key, base_url


def _get_openai_client() -> tuple[OpenAI, str]:
    """获取 OpenAI 客户端和模型名称"""
    model, api_key, base_url = _get_llm_config()
    
    client_kwargs = {}
    if api_key:
        client_kwargs["api_key"] = api_key
    if base_url:
        client_kwargs["base_url"] = base_url
    
    client = OpenAI(**client_kwargs) if client_kwargs else OpenAI()
    return client, model


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=15))
def get_categories_for_memory(memory: str) -> List[str]:
    try:
        openai_client, model = _get_openai_client()
        
        messages = [
            {"role": "system", "content": MEMORY_CATEGORIZATION_PROMPT},
            {"role": "user", "content": memory}
        ]

        logging.info(f"[Categorization] Using model: {model}")
        
        # Let OpenAI handle the pydantic parsing directly
        completion = openai_client.beta.chat.completions.parse(
            model=model,
            messages=messages,
            response_format=MemoryCategories,
            temperature=0
        )

        parsed: MemoryCategories = completion.choices[0].message.parsed
        return [cat.strip().lower() for cat in parsed.categories]

    except Exception as e:
        logging.error(f"[ERROR] Failed to get categories: {e}")
        try:
            logging.debug(f"[DEBUG] Raw response: {completion.choices[0].message.content}")
        except Exception as debug_e:
            logging.debug(f"[DEBUG] Could not extract raw response: {debug_e}")
        raise
