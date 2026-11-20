import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient


# ==============================================================================
# Helpers
# ==============================================================================

async def setup_ph_and_project(client: AsyncClient, headers: dict, studio_name: str = "Studio Arc") -> tuple[UUID, UUID]:
    ph_res = await client.post(
        "/api/v1/production-houses",
        headers=headers,
        json={"company_name": studio_name, "location": "Mumbai"},
    )
    assert ph_res.status_code == 201
    ph_id = UUID(ph_res.json()["id"])

    proj_res = await client.post(
        "/api/v1/projects",
        headers=headers,
        json={"title": f"{studio_name} Project", "genre": "Drama"},
    )
    assert proj_res.status_code == 201
    proj_id = UUID(proj_res.json()["id"])

    return ph_id, proj_id


# ==============================================================================
# Role Restrictions & Authentication Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_cannot_create_opportunity(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that Talent accounts cannot create opportunities (403 Forbidden)."""
    payload = {
        "title": "Lead Role",
        "project_id": str(uuid.uuid4()),
    }
    response = await async_client.post(
        "/api/v1/opportunities/",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 403
    assert "restricted to Production House accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_unauthenticated_opportunity_creation_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated opportunity creation is rejected (401 or 403)."""
    payload = {"title": "No Auth Role", "project_id": str(uuid.uuid4())}
    response = await async_client.post("/api/v1/opportunities/", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_opportunity_creation_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that invalid token returns 401."""
    payload = {"title": "Invalid Token Role", "project_id": str(uuid.uuid4())}
    response = await async_client.post(
        "/api/v1/opportunities/",
        headers=invalid_headers,
        json=payload,
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_opportunity_creation_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token returns 401."""
    payload = {"title": "Expired Token Role", "project_id": str(uuid.uuid4())}
    response = await async_client.post(
        "/api/v1/opportunities/",
        headers=expired_headers,
        json=payload,
    )
    assert response.status_code == 401


# ==============================================================================
# Project Reference Validation
# ==============================================================================

@pytest.mark.asyncio
async def test_create_opportunity_with_nonexistent_project_rejected(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that referencing a non-existent project returns 404."""
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Lone Studio"},
    )
    payload = {
        "title": "Lead Actor",
        "project_id": str(uuid.uuid4()),
        "role_type": "Lead",
    }
    response = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json=payload,
    )
    assert response.status_code == 404
    assert "Project not found" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_create_opportunity_under_foreign_project_rejected(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
):
    """Verifies that PH2 cannot create an opportunity under PH1's project (404 Not Found / cross-ownership block)."""
    _, ph1_proj_id = await setup_ph_and_project(async_client, ph_headers, "PH1 House")

    # PH2 sets up studio
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph2_headers,
        json={"company_name": "PH2 House"},
    )

    # PH2 tries to create opportunity referencing PH1's project
    payload = {
        "title": "Cross-Studio Casting Call",
        "project_id": str(ph1_proj_id),
        "role_type": "Supporting",
    }
    response = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph2_headers,
        json=payload,
    )
    assert response.status_code == 404
    assert "does not belong to your production house" in response.json().get("detail", "")


# ==============================================================================
# Opportunity Lifecycle & Status Management
# ==============================================================================

@pytest.mark.asyncio
async def test_create_and_retrieve_opportunity(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies creating and retrieving a casting opportunity."""
    ph_id, proj_id = await setup_ph_and_project(async_client, ph_headers, "Sun Pictures")

    payload = {
        "title": "Lead Female Protagonist",
        "project_id": str(proj_id),
        "role_type": "Lead Actress",
        "requirements": "Age 22-28, fluent in Tamil, classical dance training required.",
        "location": "Chennai / Madurai",
        "compensation": "₹15,00,000",
        "deadline": "2027-02-28",
        "status": "open",
    }
    create_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json=payload,
    )
    assert create_res.status_code == 201
    opp_data = create_res.json()
    assert opp_data["title"] == "Lead Female Protagonist"
    assert opp_data["project_id"] == str(proj_id)
    assert opp_data["production_house_id"] == str(ph_id)
    assert opp_data["role_type"] == "Lead Actress"
    assert opp_data["status"] == "open"
    assert "id" in opp_data

    opp_id = opp_data["id"]

    # Retrieve by ID (public access)
    get_res = await async_client.get(f"/api/v1/opportunities/{opp_id}")
    assert get_res.status_code == 200
    assert get_res.json()["id"] == opp_id
    assert get_res.json()["title"] == "Lead Female Protagonist"


@pytest.mark.asyncio
async def test_list_own_opportunities(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies listing opportunities created by the authenticated PH."""
    _, proj_id = await setup_ph_and_project(async_client, ph_headers, "Lyca Productions")

    await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "Opp 1", "project_id": str(proj_id), "role_type": "Lead"},
    )
    await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "Opp 2", "project_id": str(proj_id), "role_type": "Crew"},
    )

    my_res = await async_client.get("/api/v1/opportunities/my", headers=ph_headers)
    assert my_res.status_code == 200
    my_opps = my_res.json()
    assert len(my_opps) == 2
    titles = [o["title"] for o in my_opps]
    assert "Opp 1" in titles
    assert "Opp 2" in titles


@pytest.mark.asyncio
async def test_update_and_patch_opportunity(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies PUT and PATCH updates on opportunity."""
    _, proj_id = await setup_ph_and_project(async_client, ph_headers, "Mythri Movie Makers")

    create_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "Initial Casting Call", "project_id": str(proj_id)},
    )
    opp_id = create_res.json()["id"]

    # PUT complete update
    put_payload = {
        "title": "Updated Casting Title",
        "role_type": "Antagonist",
        "requirements": "Strong theatrical presence.",
        "location": "Hyderabad",
        "compensation": "Standard Scale",
        "status": "open",
    }
    put_res = await async_client.put(
        f"/api/v1/opportunities/{opp_id}",
        headers=ph_headers,
        json=put_payload,
    )
    assert put_res.status_code == 200
    assert put_res.json()["title"] == "Updated Casting Title"
    assert put_res.json()["role_type"] == "Antagonist"

    # PATCH partial update
    patch_res = await async_client.patch(
        f"/api/v1/opportunities/{opp_id}",
        headers=ph_headers,
        json={"location": "Goa"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["location"] == "Goa"
    assert patch_res.json()["title"] == "Updated Casting Title"


@pytest.mark.asyncio
async def test_close_opportunity_status(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies closing an opportunity via PATCH /{opp_id}/status."""
    _, proj_id = await setup_ph_and_project(async_client, ph_headers, "Geetha Arts")

    create_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "Open Role Call", "project_id": str(proj_id)},
    )
    opp_id = create_res.json()["id"]
    assert create_res.json()["status"] == "open"

    # Close opportunity
    close_res = await async_client.patch(
        f"/api/v1/opportunities/{opp_id}/status",
        headers=ph_headers,
        json={"status": "closed"},
    )
    assert close_res.status_code == 200
    assert close_res.json()["status"] == "closed"

    # Verify status persisted
    get_res = await async_client.get(f"/api/v1/opportunities/{opp_id}")
    assert get_res.status_code == 200
    assert get_res.json()["status"] == "closed"


@pytest.mark.asyncio
async def test_filter_opportunities_by_status_and_search(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies listing opportunities with status filter and global search."""
    _, proj_id = await setup_ph_and_project(async_client, ph_headers, "Hombale Films")

    # Create one open and one closed opportunity
    await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "Hero Role Bangalore", "project_id": str(proj_id), "status": "open", "role_type": "Lead"},
    )
    await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "Villain Role Mysore", "project_id": str(proj_id), "status": "closed", "role_type": "Villain"},
    )

    # Filter status=open
    open_res = await async_client.get("/api/v1/opportunities/?status=open")
    assert open_res.status_code == 200
    open_titles = [o["title"] for o in open_res.json()]
    assert "Hero Role Bangalore" in open_titles
    assert "Villain Role Mysore" not in open_titles

    # Filter status=closed
    closed_res = await async_client.get("/api/v1/opportunities/?status=closed")
    assert closed_res.status_code == 200
    closed_titles = [o["title"] for o in closed_res.json()]
    assert "Villain Role Mysore" in closed_titles

    # Search opportunities
    search_res = await async_client.get("/api/v1/opportunities/search?q=Bangalore")
    assert search_res.status_code == 200
    assert any("Hero Role Bangalore" in o["title"] for o in search_res.json())


@pytest.mark.asyncio
async def test_another_ph_cannot_modify_or_delete_opportunity(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
):
    """Verifies that PH2 cannot modify or delete PH1's opportunity."""
    _, proj_id = await setup_ph_and_project(async_client, ph_headers, "Creator Studio")
    create_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "Exclusive Opp", "project_id": str(proj_id)},
    )
    opp_id = create_res.json()["id"]

    # PH2 creates its studio
    await async_client.post("/api/v1/production-houses", headers=ph2_headers, json={"company_name": "Rival Studio"})

    # PH2 attempts PUT
    ph2_put = await async_client.put(
        f"/api/v1/opportunities/{opp_id}",
        headers=ph2_headers,
        json={"title": "Hijacked Title", "status": "open"},
    )
    assert ph2_put.status_code == 404

    # PH2 attempts status patch
    ph2_patch = await async_client.patch(
        f"/api/v1/opportunities/{opp_id}/status",
        headers=ph2_headers,
        json={"status": "closed"},
    )
    assert ph2_patch.status_code == 404

    # PH2 attempts DELETE
    ph2_del = await async_client.delete(
        f"/api/v1/opportunities/{opp_id}",
        headers=ph2_headers,
    )
    assert ph2_del.status_code == 404


@pytest.mark.asyncio
async def test_delete_opportunity(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies owner can delete an opportunity."""
    _, proj_id = await setup_ph_and_project(async_client, ph_headers, "Deleting Studio")
    create_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"title": "To Be Deleted", "project_id": str(proj_id)},
    )
    opp_id = create_res.json()["id"]

    del_res = await async_client.delete(f"/api/v1/opportunities/{opp_id}", headers=ph_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/opportunities/{opp_id}")
    assert get_res.status_code == 404
