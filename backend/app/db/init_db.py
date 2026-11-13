from sqlalchemy import text
from app.core.logging import logger
from app.db.base import Base
from app.db.session import engine


async def init_db() -> bool:
    """Verifies database connectivity and initializes database schema if necessary."""
    try:
        async with engine.begin() as conn:
            # Simple connection verification ping
            await conn.execute(text("SELECT 1"))
            logger.info("Database connectivity established successfully.")

            # Create tables registered on Base metadata (for dev/testing)
            await conn.run_sync(Base.metadata.create_all)
            logger.info("Database schema initialized.")
            return True
    except Exception as exc:
        logger.error(f"Failed to initialize database connectivity: {exc}")
        return False
