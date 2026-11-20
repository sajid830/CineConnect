import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient


# ==============================================================================
# Authentication & Role Restrictions
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_cannot_access_ph_me_endpoint(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that a Talent persona cannot access Production House endpoints (403 Forbidden)."""
    response = await async_client.get("/api/v1/production-houses/me", headers=talent_headers)
    assert response.status_code == 403
    assert "restricted to Production House accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_talent_cannot_update_ph_me_endpoint(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that a Talent persona cannot update Production House profile (403 Forbidden)."""
    payload = {"company_name": "Talent Hack Studio"}
    response = await async_client.put(
        "/api/v1/production-houses/me",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_unauthenticated_access_to_ph_me_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated request to /me is rejected (401 or 403)."""
    response = await async_client.get("/api/v1/production-houses/me")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_access_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that malformed JWT token is rejected (401 Unauthorized)."""
    response = await async_client.get("/api/v1/production-houses/me", headers=invalid_headers)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_access_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired JWT token is rejected (401 Unauthorized)."""
    response = await async_client.get("/api/v1/production-houses/me", headers=expired_headers)
    assert response.status_code == 401


# ==============================================================================
# Production House Lifecycle & Retrieval
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_user_me_before_creation_returns_404(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that a Production House user without a profile gets 404."""
    response = await async_client.get("/api/v1/production-houses/me", headers=ph_headers)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_ph_user_creates_and_retrieves_production_house(
    async_client: AsyncClient,
    ph_headers: dict,
    ph_user_id: UUID,
):
    """Verifies successful creation and subsequent retrieval of a Production House profile."""
    payload = {
        "company_name": "Studio Noir Productions",
        "description": "Boutique indie cinema and documentary production house.",
        "location": "Mumbai, India",
        "specialization": "Feature Films, Documentaries",
        "website": "https://studionoir.example.com",
        "logo_url": "https://cdn.example.com/logo.png",
    }
    create_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json=payload,
    )
    assert create_res.status_code == 201
    created_data = create_res.json()
    assert created_data["company_name"] == "Studio Noir Productions"
    assert created_data["user_id"] == str(ph_user_id)
    assert "id" in created_data
    assert created_data["website"] == "https://studionoir.example.com"
    assert created_data["logo_url"] == "https://cdn.example.com/logo.png"
    assert created_data["email"] == "producer@testcineconnect.com"
    assert created_data["is_verified"] is False

    # Verify GET /me retrieves the newly created profile
    me_res = await async_client.get("/api/v1/production-houses/me", headers=ph_headers)
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["id"] == created_data["id"]
    assert me_data["company_name"] == "Studio Noir Productions"
    assert me_data["email"] == "producer@testcineconnect.com"
    assert me_data["is_verified"] is False


@pytest.mark.asyncio
async def test_update_production_house_profile(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies updating production house profile fields."""
    initial_payload = {
        "company_name": "Original Name Films",
        "description": "Original description",
        "location": "Chennai, India",
    }
    create_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json=initial_payload,
    )
    assert create_res.status_code == 201

    update_payload = {
        "company_name": "Updated Name Studios",
        "description": "Updated international distribution house.",
        "location": "Hyderabad, India",
        "specialization": "Action, Sci-Fi",
        "website": "https://updatedstudios.com",
        "logo_url": "https://cdn.updatedstudios.com/logo.png",
    }
    update_res = await async_client.put(
        "/api/v1/production-houses/me",
        headers=ph_headers,
        json=update_payload,
    )
    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["company_name"] == "Updated Name Studios"
    assert updated_data["location"] == "Hyderabad, India"
    assert updated_data["specialization"] == "Action, Sci-Fi"
    assert updated_data["website"] == "https://updatedstudios.com"


@pytest.mark.asyncio
async def test_get_production_house_by_id(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies public retrieval of a production house by its UUID."""
    create_payload = {
        "company_name": "Public Cinema Hub",
        "location": "Bengaluru, India",
    }
    create_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json=create_payload,
    )
    house_id = create_res.json()["id"]

    # Public retrieval without headers
    get_res = await async_client.get(f"/api/v1/production-houses/{house_id}")
    assert get_res.status_code == 200
    assert get_res.json()["company_name"] == "Public Cinema Hub"


@pytest.mark.asyncio
async def test_get_production_house_by_nonexistent_id_returns_404(async_client: AsyncClient):
    """Verifies that requesting a non-existent production house returns 404."""
    random_id = uuid.uuid4()
    get_res = await async_client.get(f"/api/v1/production-houses/{random_id}")
    assert get_res.status_code == 404
    assert "not found" in get_res.json().get("detail", "").lower()


# ==============================================================================
# Constraints & Ownership Enforcement
# ==============================================================================

@pytest.mark.asyncio
async def test_prevent_duplicate_production_house_per_user(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that one user can own only one production house (409 Conflict)."""
    payload = {
        "company_name": "First Studio",
        "description": "Primary Studio",
    }
    first_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json=payload,
    )
    assert first_res.status_code == 201

    duplicate_payload = {
        "company_name": "Second Studio",
        "description": "Attempted duplicate studio",
    }
    duplicate_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json=duplicate_payload,
    )
    assert duplicate_res.status_code == 409
    assert "already exists" in duplicate_res.json().get("detail", "")


@pytest.mark.asyncio
async def test_production_house_ownership_isolation(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
):
    """Verifies that PH2 user cannot access or modify PH1's profile via /me."""
    # PH1 creates profile
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "PH1 Media"},
    )

    # PH2 before creating has 404
    ph2_me_res = await async_client.get("/api/v1/production-houses/me", headers=ph2_headers)
    assert ph2_me_res.status_code == 404

    # PH2 creates profile
    ph2_create_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph2_headers,
        json={"company_name": "PH2 Studios"},
    )
    assert ph2_create_res.status_code == 201

    # Verify both have distinct profiles
    ph1_data = (await async_client.get("/api/v1/production-houses/me", headers=ph_headers)).json()
    ph2_data = (await async_client.get("/api/v1/production-houses/me", headers=ph2_headers)).json()

    assert ph1_data["company_name"] == "PH1 Media"
    assert ph2_data["company_name"] == "PH2 Studios"
    assert ph1_data["id"] != ph2_data["id"]


# ==============================================================================
# Discovery & Related Resources
# ==============================================================================

@pytest.mark.asyncio
async def test_list_and_search_production_houses(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies listing and searching production houses."""
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Universal Motion Pictures", "specialization": "VFX", "location": "Kochi"},
    )

    # List
    list_res = await async_client.get("/api/v1/production-houses")
    assert list_res.status_code == 200
    assert len(list_res.json()) >= 1

    # Search by keyword
    search_res = await async_client.get("/api/v1/production-houses/search?q=Universal")
    assert search_res.status_code == 200
    results = search_res.json()
    assert any(h["company_name"] == "Universal Motion Pictures" for h in results)

    # Search with location filter
    loc_search = await async_client.get("/api/v1/production-houses/search?location=Kochi")
    assert loc_search.status_code == 200
    assert any(h["location"] == "Kochi" for h in loc_search.json())


@pytest.mark.asyncio
async def test_get_production_house_projects_and_opportunities_empty(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies fetching projects and opportunities for a newly created PH returns empty list."""
    create_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Fresh Studio"},
    )
    house_id = create_res.json()["id"]

    proj_res = await async_client.get(f"/api/v1/production-houses/{house_id}/projects")
    assert proj_res.status_code == 200
    assert proj_res.json() == []

    opp_res = await async_client.get(f"/api/v1/production-houses/{house_id}/opportunities")
    assert opp_res.status_code == 200
    assert opp_res.json() == []
