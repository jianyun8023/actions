import os

from urllib.parse import urlparse
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# load .env file (make sure you have DATABASE_URL set)
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./openmemory.db")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is not set in environment")

# 根据数据库类型设置连接参数
parsed_url = urlparse(DATABASE_URL)
if parsed_url.scheme.startswith("sqlite"):
    connect_args = {"check_same_thread": False}  # SQLite 专用
else:
    connect_args = {}  # PostgreSQL 和其他数据库不需要此参数

# SQLAlchemy engine & session
engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()

# Dependency for FastAPI
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

