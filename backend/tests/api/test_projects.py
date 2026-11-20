import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient


# ==============================================================================
# Helper to create production house for tests
# ==============================================================================

async def setup_production_house(client: AsyncClient, headers: dict, name: str = "Test Studio") -> UUID:
    res = await client.post(
        "/api/v1/production-houses",
        headers=headers,
        json={"company_name": name, "location": "Mumbai"},
    )
    assert res.status_code == 201
    return UUID(res.json()["id"])


# ==============================================================================
# Role Restrictions & Authentication Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_cannot_create_project(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that a Talent account cannot create a project (403 Forbidden)."""
    payload = {
        "title": "Unauthorized Project",
        "genre": "Drama",
    }
    response = await async_client.post(
        "/api/v1/projects",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 403
    assert "restricted to Production House accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_unauthenticated_project_creation_rejected(async_client: AsyncClient):
    """Verifies that project creation without authentication returns 401 or 403."""
    response = await async_client.post("/api/v1/projects", json={"title": "No Auth"})
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_project_creation_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that malformed token returns 401."""
    response = await async_client.post(
        "/api/v1/projects",
        headers=invalid_headers,
        json={"title": "Invalid Token Project"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_project_creation_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token returns 401."""
    response = await async_client.post(
        "/api/v1/projects",
        headers=expired_headers,
        json={"title": "Expired Token Project"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_project_without_production_house_profile_rejected(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that a Production House user who has not created a PH profile cannot create a project (400 Bad Request)."""
    payload = {
        "title": "Orphan Project",
        "genre": "Sci-Fi",
    }
    response = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json=payload,
    )
    assert response.status_code == 400
    assert "must create a Production House profile" in response.json().get("detail", "")


# ==============================================================================
# Project Lifecycle (CRUD)
# ==============================================================================

@pytest.mark.asyncio
async def test_create_and_retrieve_project(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies project creation under an existing PH profile and subsequent retrieval."""
    house_id = await setup_production_house(async_client, ph_headers, "Eros International")

    project_payload = {
        "title": "Chronicles of the Deccan",
        "description": "Historical epic drama set in 17th century Deccan.",
        "status": "pre_production",
        "genre": "Historical Epic",
        "start_date": "2027-01-15",
        "end_date": "2027-08-30",
        "budget": "$5,000,000",
    }
    create_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json=project_payload,
    )
    assert create_res.status_code == 201
    proj_data = create_res.json()
    assert proj_data["title"] == "Chronicles of the Deccan"
    assert proj_data["production_house_id"] == str(house_id)
    assert proj_data["status"] == "pre_production"
    assert proj_data["genre"] == "Historical Epic"
    assert "id" in proj_data

    project_id = proj_data["id"]

    # Retrieve by ID (public access)
    get_res = await async_client.get(f"/api/v1/projects/{project_id}")
    assert get_res.status_code == 200
    retrieved = get_res.json()
    assert retrieved["id"] == project_id
    assert retrieved["title"] == "Chronicles of the Deccan"
    assert retrieved["budget"] == "$5,000,000"


@pytest.mark.asyncio
async def test_list_own_projects(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies listing projects belonging to the logged-in production house."""
    await setup_production_house(async_client, ph_headers, "Excel Entertainment")

    # Create two projects
    await async_client.post("/api/v1/projects", headers=ph_headers, json={"title": "Project Alpha"})
    await async_client.post("/api/v1/projects", headers=ph_headers, json={"title": "Project Beta"})

    my_res = await async_client.get("/api/v1/projects/my", headers=ph_headers)
    assert my_res.status_code == 200
    my_projects = my_res.json()
    assert len(my_projects) == 2
    titles = [p["title"] for p in my_projects]
    assert "Project Alpha" in titles
    assert "Project Beta" in titles


@pytest.mark.asyncio
async def test_update_project(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies updating project fields via PUT and PATCH."""
    await setup_production_house(async_client, ph_headers, "Dharma Productions")

    create_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Working Title", "status": "development"},
    )
    project_id = create_res.json()["id"]

    # PUT complete update
    put_payload = {
        "title": "Final Confirmed Title",
        "description": "Updated full synopsis.",
        "status": "production",
        "genre": "Romantic Drama",
        "budget": "$2,000,000",
    }
    put_res = await async_client.put(
        f"/api/v1/projects/{project_id}",
        headers=ph_headers,
        json=put_payload,
    )
    assert put_res.status_code == 200
    assert put_res.json()["title"] == "Final Confirmed Title"
    assert put_res.json()["status"] == "production"

    # PATCH partial update
    patch_res = await async_client.patch(
        f"/api/v1/projects/{project_id}",
        headers=ph_headers,
        json={"status": "post_production"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["status"] == "post_production"
    assert patch_res.json()["title"] == "Final Confirmed Title"


@pytest.mark.asyncio
async def test_delete_project(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies deleting a project removes it from future queries."""
    await setup_production_house(async_client, ph_headers, "Yash Raj Films")

    create_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Project To Cancel"},
    )
    project_id = create_res.json()["id"]

    # Delete project
    del_res = await async_client.delete(f"/api/v1/projects/{project_id}", headers=ph_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/projects/{project_id}")
    assert get_res.status_code == 404


# ==============================================================================
# Cross-User Ownership Enforcement
# ==============================================================================

@pytest.mark.asyncio
async def test_another_ph_cannot_modify_or_delete_project(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
):
    """Verifies that PH2 cannot update or delete a project owned by PH1 (403 Forbidden)."""
    # PH1 creates studio and project
    await setup_production_house(async_client, ph_headers, "Studio One")
    create_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Studio One Exclusive Project"},
    )
    project_id = create_res.json()["id"]

    # PH2 creates studio
    await setup_production_house(async_client, ph2_headers, "Studio Two")

    # PH2 attempts to PUT update
    ph2_put = await async_client.put(
        f"/api/v1/projects/{project_id}",
        headers=ph2_headers,
        json={"title": "Hijacked Project Title"},
    )
    assert ph2_put.status_code == 403
    assert "do not own this project" in ph2_put.json().get("detail", "")

    # PH2 attempts to PATCH update
    ph2_patch = await async_client.patch(
        f"/api/v1/projects/{project_id}",
        headers=ph2_headers,
        json={"status": "cancelled"},
    )
    assert ph2_patch.status_code == 403

    # PH2 attempts to DELETE
    ph2_del = await async_client.delete(
        f"/api/v1/projects/{project_id}",
        headers=ph2_headers,
    )
    assert ph2_del.status_code == 403

    # Project should remain intact
    verify_res = await async_client.get(f"/api/v1/projects/{project_id}")
    assert verify_res.status_code == 200
    assert verify_res.json()["title"] == "Studio One Exclusive Project"


# ==============================================================================
# Public Discovery & Search
# ==============================================================================

@pytest.mark.asyncio
async def test_list_and_search_projects(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies listing and filtering projects by query, status, and genre."""
    await setup_production_house(async_client, ph_headers, "T-Series Films")

    await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Midnight In Mumbai", "genre": "Neo-Noir", "status": "production"},
    )
    await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Sunshine Days", "genre": "Comedy", "status": "development"},
    )

    # List all
    list_res = await async_client.get("/api/v1/projects")
    assert list_res.status_code == 200
    assert len(list_res.json()) >= 2

    # Search by keyword
    search_res = await async_client.get("/api/v1/projects/search?q=Mumbai")
    assert search_res.status_code == 200
    results = search_res.json()
    assert len(results) >= 1
    assert any("Midnight In Mumbai" in p["title"] for p in results)

    # Search with genre filter
    genre_res = await async_client.get("/api/v1/projects/search?genre=Comedy")
    assert genre_res.status_code == 200
    assert any("Sunshine Days" in p["title"] for p in genre_res.json())


@pytest.mark.asyncio
async def test_get_nonexistent_project_returns_404(async_client: AsyncClient):
    """Verifies that requesting a non-existent project ID returns 404."""
    random_id = uuid.uuid4()
    get_res = await async_client.get(f"/api/v1/projects/{random_id}")
    assert get_res.status_code == 404
    assert "not found" in get_res.json().get("detail", "").lower()
