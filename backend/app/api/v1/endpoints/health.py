import time
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.logging import logger
from app.db.session import get_db, get_pool_status
from app.schemas.health import (
    DetailedHealthResponse,
    DatabaseHealthResponse,
    DatabaseUnhealthyResponse,
)

router = APIRouter()


@router.get(
    "",
    response_model=DetailedHealthResponse,
    summary="API v1 Health Status",
    description="Returns API service health, active environment, and version.",
)
async def get_api_health() -> DetailedHealthResponse:
    return DetailedHealthResponse(
        status="healthy",
        service="cineconnect-backend",
        environment=settings.APP_ENV,
        version="1.0.0",
        timestamp=datetime.now(timezone.utc).isoformat(),
    )


@router.get(
    "/db",
    response_model=DatabaseHealthResponse,
    responses={
        503: {
            "model": DatabaseUnhealthyResponse,
            "description": "Database is unreachable or unhealthy",
        }
    },
    summary="Database Connectivity Check",
    description="Performs an asynchronous SELECT 1 query to verify live PostgreSQL connectivity.",
)
async def check_database_health(db: AsyncSession = Depends(get_db)):
    start_time = time.perf_counter()
    try:
        result = await db.execute(text("SELECT 1"))
        scalar_val = result.scalar()
        latency_ms = round((time.perf_counter() - start_time) * 1000, 2)

        if scalar_val == 1:
            return DatabaseHealthResponse(
                status="healthy",
                database="connected",
                latency_ms=latency_ms,
                pool=get_pool_status(),
            )
        else:
            logger.warning("Database query executed but returned unexpected result.")
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={
                    "status": "unhealthy",
                    "database": "disconnected",
                    "detail": "Database returned unexpected response",
                },
            )
    except Exception as exc:
        logger.error(f"Database health check failed: {exc}", exc_info=False)
        # Never expose internal credentials, passwords, or connection strings to client
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "database": "disconnected",
                "detail": "Database connection failed",
            },
        )
