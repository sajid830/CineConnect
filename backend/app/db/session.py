import asyncio
from typing import Any, AsyncGenerator, Dict
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from app.core.config import settings
from app.core.logging import logger

# Construct engine based on target database driver
db_url = settings.async_database_url

if "sqlite" in db_url:
    engine = create_async_engine(
        db_url,
        echo=(settings.LOG_LEVEL.upper() == "DEBUG"),
        future=True,
    )
else:
    engine_kwargs: Dict[str, Any] = {
        "echo": (settings.LOG_LEVEL.upper() == "DEBUG"),
        "future": True,
        "pool_size": settings.DB_POOL_SIZE,
        "max_overflow": settings.DB_MAX_OVERFLOW,
        "pool_timeout": settings.DB_POOL_TIMEOUT,
        "pool_recycle": settings.DB_POOL_RECYCLE,
        "pool_pre_ping": True,
        "pool_use_lifo": settings.DB_POOL_USE_LIFO,
    }
    if "asyncpg" in db_url:
        engine_kwargs["connect_args"] = {
            "command_timeout": settings.DB_COMMAND_TIMEOUT,
        }

    engine = create_async_engine(db_url, **engine_kwargs)

# Async session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


def get_pool_status() -> Dict[str, Any]:
    """Returns current SQLAlchemy connection pool metrics and configured timings."""
    pool = engine.pool
    status_info: Dict[str, Any] = {
        "pool_class": type(pool).__name__,
        "configured_pool_size": settings.DB_POOL_SIZE,
        "configured_max_overflow": settings.DB_MAX_OVERFLOW,
        "pool_timeout_seconds": settings.DB_POOL_TIMEOUT,
        "pool_recycle_seconds": settings.DB_POOL_RECYCLE,
        "pool_use_lifo": settings.DB_POOL_USE_LIFO,
        "command_timeout_seconds": settings.DB_COMMAND_TIMEOUT,
    }
    for attr in ("size", "checkedin", "checkedout", "overflow"):
        member = getattr(pool, attr, None)
        if callable(member):
            try:
                status_info[attr] = member()
            except Exception:
                pass
    return status_info


async def warm_pool(min_connections: int | None = None) -> int:
    """Asynchronously pre-warms PostgreSQL pool connections so initial requests have zero cold-start lag."""
    if "sqlite" in db_url:
        return 0

    target = min_connections if min_connections is not None else settings.DB_POOL_WARMUP_CONNECTIONS
    target = max(0, min(target, settings.DB_POOL_SIZE))
    if target == 0:
        return 0

    async def _ping_once() -> bool:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True

    results = await asyncio.gather(*(_ping_once() for _ in range(target)), return_exceptions=True)
    warmed = sum(1 for r in results if r is True)
    logger.info(f"Database connection pool warmed ({warmed}/{target} connections ready).")
    return warmed


async def dispose_pool() -> None:
    """Cleanly disposes all pooled database connections on shutdown."""
    try:
        await engine.dispose()
        logger.info("Database connection pool disposed cleanly.")
    except Exception as exc:
        logger.warning(f"Error disposing database connection pool: {exc}")


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency injection generator yielding an async database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception as exc:
            logger.error(f"Database session error: {exc}", exc_info=True)
            await session.rollback()
            raise
        finally:
            await session.close()
