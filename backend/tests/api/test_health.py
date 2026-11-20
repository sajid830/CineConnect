import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_root_health_endpoint(async_client: AsyncClient):
    """Verifies GET /health returns expected operational payload."""
    response = await async_client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "cineconnect-backend"


@pytest.mark.asyncio
async def test_api_v1_health_endpoint(async_client: AsyncClient):
    """Verifies GET /api/v1/health returns detailed runtime environment metadata."""
    response = await async_client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "cineconnect-backend"
    assert "environment" in data
    assert "version" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_database_health_endpoint(async_client: AsyncClient):
    """Verifies GET /api/v1/health/db successfully executes a query against PostgreSQL test DB."""
    response = await async_client.get("/api/v1/health/db")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"
    assert "latency_ms" in data
    assert isinstance(data["latency_ms"], (int, float))
