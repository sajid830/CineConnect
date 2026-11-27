from contextlib import asynccontextmanager
from typing import Optional
from fastapi import FastAPI, Request, WebSocket, Query, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.openapi.utils import get_openapi
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.v1.api import api_router
from app.api.websocket import chat_websocket_endpoint, events_websocket_endpoint
from app.core.config import settings
from app.core.logging import logger
from app.db.init_db import init_db
from app.db.session import dispose_pool
from app.schemas.health import HealthResponse
from app.services.realtime import realtime_pooler


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle management."""
    logger.info(f"Starting {settings.APP_NAME} in '{settings.APP_ENV}' environment...")
    logger.info(f"Configured CORS origins: {settings.CORS_ORIGINS}")

    # Production JWT configuration validation
    settings.validate_production_jwt_config()

    # Database connectivity verification
    db_connected = await init_db()
    if not db_connected:
        logger.warning(
            "PostgreSQL database was not reachable at startup. "
            "Database connectivity will be re-attempted on request."
        )

    # Storage buckets initialization (non-blocking if MinIO is not running)
    try:
        from app.services.storage import init_storage_buckets
        init_storage_buckets()
    except Exception as e:
        logger.warning(f"MinIO bucket initialization deferred: {e}")

    # Start asynchronous realtime event pooler
    realtime_pooler.start()

    yield

    # Stop realtime event pooler
    await realtime_pooler.stop()

    # Clean up asynchronous HTTP client on shutdown
    try:
        from app.core.security import jwk_manager
        await jwk_manager.aclose()
    except Exception as e:
        logger.warning(f"Error closing JWK manager client: {e}")

    # Dispose pooled PostgreSQL connections cleanly
    await dispose_pool()

    logger.info(f"Shutting down {settings.APP_NAME}...")


app = FastAPI(
    title=settings.APP_NAME,
    description="CineConnect Backend API – Enterprise asynchronous platform supporting Talent and Production House interfaces.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
    swagger_ui_parameters={"persistAuthorization": True},
)

# Custom OpenAPI schema to register BearerAuth for Swagger UI
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Enter Supabase JWT token (Bearer token).",
        }
    }
    # Apply security globally or per endpoint
    openapi_schema["security"] = [{"BearerAuth": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
)


# Exception Handlers
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "code": exc.status_code,
            "detail": exc.detail,
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "status": "error",
            "code": status.HTTP_422_UNPROCESSABLE_ENTITY,
            "detail": "Request validation failed",
            "errors": exc.errors(),
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception on {request.method} {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "status": "error",
            "code": status.HTTP_500_INTERNAL_SERVER_ERROR,
            "detail": "An internal server error occurred.",
        },
    )


# Root Health Check (GET /health)
@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["Root"],
    summary="Root Service Health Status",
)
async def root_health() -> HealthResponse:
    """Root health check returning service operational status."""
    return HealthResponse(
        status="healthy",
        service="cineconnect-backend",
    )


# Real-Time Chat WebSocket Endpoint
@app.websocket("/ws/chat")
async def websocket_chat_route(websocket: WebSocket, token: Optional[str] = Query(None)):
    """WebSocket endpoint for real-time direct chat."""
    await chat_websocket_endpoint(websocket, token)


# Real-Time Events WebSocket Endpoint (Jobs, Projects, Applications)
@app.websocket("/ws/events")
async def websocket_events_route(websocket: WebSocket, token: Optional[str] = Query(None)):
    """WebSocket endpoint for real-time asynchronous release and application updates."""
    await events_websocket_endpoint(websocket, token)


# Include API v1 Router
app.include_router(api_router, prefix=settings.API_V1_PREFIX)
