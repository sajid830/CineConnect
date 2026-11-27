from sqlalchemy import text
from app.core.logging import logger
from app.db.session import engine, warm_pool


async def init_db() -> bool:
    """Verifies PostgreSQL database connectivity and pre-warms the async connection pool."""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
            logger.info("Database connectivity established successfully.")
        await warm_pool()
        return True
    except Exception as exc:
        logger.error(f"Failed to initialize database connectivity: {exc}")
        return False
