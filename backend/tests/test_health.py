import pytest
from unittest.mock import AsyncMock
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.db.session import get_db


@pytest.mark.asyncio
async def test_root_health(async_client: AsyncClient):
    """Verifies GET /health returns expected foundation payload."""
    response = await async_client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "cineconnect-backend"


@pytest.mark.asyncio
async def test_api_v1_health(async_client: AsyncClient):
    """Verifies GET /api/v1/health returns detailed service metadata."""
    response = await async_client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "cineconnect-backend"
    assert "environment" in data
    assert "version" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_database_health_success(async_client: AsyncClient):
    """Verifies GET /api/v1/health/db successfully executes query against connected database."""
    response = await async_client.get("/api/v1/health/db")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"
    assert "latency_ms" in data
    assert isinstance(data["latency_ms"], (int, float))


@pytest.mark.asyncio
async def test_database_health_failure():
    """Verifies GET /api/v1/health/db returns 503 without credential leakage when DB query fails."""
    mock_db = AsyncMock()
    mock_db.execute.side_effect = Exception("Simulated connection refused: host postgres unreachable")

    async def override_failing_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_failing_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/api/v1/health/db")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "unhealthy"
        assert data["database"] == "disconnected"
        assert data["detail"] == "Database connection failed"
        # Confirm no credentials/passwords leaked
        assert "password" not in response.text.lower()
        assert "secret" not in response.text.lower()

    app.dependency_overrides.clear()
