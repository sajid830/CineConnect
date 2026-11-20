from uuid import UUID
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_unauthenticated_user_access_rejected(async_client: AsyncClient):
    """Verifies that accessing protected user endpoints without credentials returns 401 or 403."""
    response = await async_client.get("/api/v1/users/me")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_rejected(async_client: AsyncClient, invalid_headers: dict):
    """Verifies that accessing protected user endpoints with a malformed token returns 401."""
    response = await async_client.get("/api/v1/users/me", headers=invalid_headers)
    assert response.status_code == 401
    assert "Invalid or expired" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_expired_token_rejected(async_client: AsyncClient, expired_headers: dict):
    """Verifies that accessing protected user endpoints with an expired token returns 401."""
    response = await async_client.get("/api/v1/users/me", headers=expired_headers)
    assert response.status_code == 401
    assert "Invalid or expired" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_talent_user_profile_sync_and_retrieval(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that an authenticated Supabase user is automatically synchronized and retrieved."""
    response = await async_client.get("/api/v1/users/me", headers=talent_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(talent_user_id)
    assert data["email"] == "talent@testcineconnect.com"
    assert data["account_type"] == "talent"
    assert data["full_name"] == "Test Talent User"
    assert data["is_verified"] is False
    assert data["experience_years"] == 0


@pytest.mark.asyncio
async def test_update_talent_user_profile(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies updating talent profile fields."""
    # First sync user
    await async_client.get("/api/v1/users/me", headers=talent_headers)

    update_payload = {
        "full_name": "Updated Talent Name",
        "role": "Cinematographer",
        "location": "Mumbai, India",
        "bio": "Specialized in anamorphic cinematography and visual storytelling.",
        "phone": "+919876543210",
        "experience_years": 7,
        "skills": ["Cinematography", "Lighting", "Drone Operation"],
    }
    response = await async_client.put(
        "/api/v1/users/me",
        headers=talent_headers,
        json=update_payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(talent_user_id)
    assert data["full_name"] == "Updated Talent Name"
    assert data["role"] == "Cinematographer"
    assert data["experience_years"] == 7
    assert data["skills"] == ["Cinematography", "Lighting", "Drone Operation"]
