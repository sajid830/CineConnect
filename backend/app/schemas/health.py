from typing import Any, Dict, Optional
from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Basic service health check response."""
    status: str = Field(..., json_schema_extra={"example": "healthy"})
    service: str = Field(..., json_schema_extra={"example": "cineconnect-backend"})


class DetailedHealthResponse(HealthResponse):
    """Detailed health check response including environment context."""
    environment: str = Field(..., json_schema_extra={"example": "local"})
    version: str = Field(..., json_schema_extra={"example": "1.0.0"})
    timestamp: str


class DatabaseHealthResponse(BaseModel):
    """Database connectivity health check response."""
    status: str = Field(..., json_schema_extra={"example": "healthy"})
    database: str = Field(..., json_schema_extra={"example": "connected"})
    latency_ms: Optional[float] = Field(None, json_schema_extra={"example": 1.25})
    pool: Optional[Dict[str, Any]] = None


class DatabaseUnhealthyResponse(BaseModel):
    """Database unhealthy response (never exposing credentials)."""
    status: str = Field(..., json_schema_extra={"example": "unhealthy"})
    database: str = Field(..., json_schema_extra={"example": "disconnected"})
    detail: str = Field(..., json_schema_extra={"example": "Database connection failed"})
