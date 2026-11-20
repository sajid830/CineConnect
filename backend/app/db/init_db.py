from sqlalchemy import text
from app.core.logging import logger
from app.db.session import engine


async def init_db() -> bool:
    """Verifies PostgreSQL database connectivity."""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
            logger.info("Database connectivity established successfully.")
            return True
    except Exception as exc:
        logger.error(f"Failed to initialize database connectivity: {exc}")
        return False
