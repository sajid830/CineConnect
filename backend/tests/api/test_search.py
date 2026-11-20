"""Search & Discovery Domain Integration Tests.

Validates unified global search across talent users, production houses, and
casting opportunities, as well as entity-specific search endpoints, query
validation, pagination, and role-agnostic public discovery.
"""
import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient

from app.main import app


# ==============================================================================
# Helper Setup Functions
# ==============================================================================

async def setup_search_corpus(
    client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
    keyword: str = "AuraQuest",
) -> dict:
    """Creates a linked set of entities sharing a unique keyword for search verification."""
    # 1. Update Talent Profile with the keyword
    update_user_res = await client.put(
        "/api/v1/users/me",
        headers=talent_headers,
        json={
            "full_name": f"{keyword} Actor",
            "role": "Method Actor",
            "location": "Bengaluru",
            "bio": f"Lead performer specializing in {keyword} drama.",
        },
    )
    assert update_user_res.status_code == 200
    user_data = update_user_res.json()

    # 2. Create Production House with the keyword
    ph_res = await client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={
            "company_name": f"{keyword} Pictures",
            "description": f"Award-winning {keyword} cinematic productions.",
            "location": "Bengaluru",
            "specialization": "Feature Films",
        },
    )
    assert ph_res.status_code == 201
    ph_data = ph_res.json()
    ph_id = ph_data["id"]

    # 3. Create Project under Production House
    proj_res = await client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={
            "title": f"{keyword} Chronicles",
            "description": f"An epic sci-fi saga by {keyword}.",
            "genre": "Sci-Fi",
            "status": "development",
        },
    )
    assert proj_res.status_code == 201
    proj_data = proj_res.json()
    proj_id = proj_data["id"]

    # 4. Create Casting Opportunity under Project
    opp_res = await client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={
            "project_id": proj_id,
            "title": f"{keyword} Protagonist",
            "role_type": "Lead",
            "requirements": f"Experienced actor familiar with {keyword} themes.",
            "location": "Bengaluru",
            "compensation": "50000 per day",
        },
    )
    assert opp_res.status_code == 201
    opp_data = opp_res.json()

    return {
        "user": user_data,
        "production_house": ph_data,
        "project": proj_data,
        "opportunity": opp_data,
        "keyword": keyword,
    }


# ==============================================================================
# Route Registration & Smoke
# ==============================================================================

def test_search_routes_registered():
    """Verifies search endpoints are mounted on the FastAPI application."""
    routes = [getattr(r, "path", "") for r in app.routes]
    assert any("/search" in r for r in routes)
    assert any("/api/v1/search/" in r for r in routes)


# ==============================================================================
# Unified Global Search Tests
# ==============================================================================

@pytest.mark.asyncio
async def test_global_search_unified_results(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies that unified global search finds users, production houses, and opportunities."""
    keyword = f"GlobalKey{uuid.uuid4().hex[:6]}"
    corpus = await setup_search_corpus(async_client, talent_headers, ph_headers, keyword=keyword)

    response = await async_client.get(f"/api/v1/search/?q={keyword}")
    assert response.status_code == 200
    data = response.json()

    assert data["query"] == keyword
    assert "users" in data
    assert "production_houses" in data
    assert "opportunities" in data

    # Verify each entity type matches
    user_ids = [u["id"] for u in data["users"]]
    assert corpus["user"]["id"] in user_ids

    ph_ids = [p["id"] for p in data["production_houses"]]
    assert corpus["production_house"]["id"] in ph_ids

    opp_ids = [o["id"] for o in data["opportunities"]]
    assert corpus["opportunity"]["id"] in opp_ids


@pytest.mark.asyncio
async def test_global_search_unauthenticated_public_access(async_client: AsyncClient):
    """Verifies unified global search is publicly accessible without an auth token."""
    response = await async_client.get("/api/v1/search/?q=cinema")
    assert response.status_code == 200
    data = response.json()
    assert "users" in data
    assert "production_houses" in data
    assert "opportunities" in data


@pytest.mark.asyncio
async def test_global_search_empty_query_rejected(async_client: AsyncClient):
    """Verifies that an empty query string is rejected with 422 Unprocessable Entity."""
    response = await async_client.get("/api/v1/search/?q=")
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_global_search_missing_query_parameter_rejected(async_client: AsyncClient):
    """Verifies that omitting the 'q' parameter returns 422."""
    response = await async_client.get("/api/v1/search/")
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_global_search_limit_boundaries(async_client: AsyncClient):
    """Verifies boundary validation for the 'limit' query parameter (1 to 50)."""
    # limit below minimum (0 < 1)
    res_under = await async_client.get("/api/v1/search/?q=film&limit=0")
    assert res_under.status_code == 422

    # limit above maximum (51 > 50)
    res_over = await async_client.get("/api/v1/search/?q=film&limit=51")
    assert res_over.status_code == 422

    # valid boundary limits
    res_min = await async_client.get("/api/v1/search/?q=film&limit=1")
    assert res_min.status_code == 200

    res_max = await async_client.get("/api/v1/search/?q=film&limit=50")
    assert res_max.status_code == 200


@pytest.mark.asyncio
async def test_global_search_no_matching_records(async_client: AsyncClient):
    """Verifies global search returns empty lists when no records match."""
    response = await async_client.get("/api/v1/search/?q=NonExistentEntityQuery999Zz")
    assert response.status_code == 200
    data = response.json()
    assert data["users"] == []
    assert data["production_houses"] == []
    assert data["opportunities"] == []


# ==============================================================================
# Entity-Specific Search: Users
# ==============================================================================

@pytest.mark.asyncio
async def test_users_search_filters_and_pagination(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies user search filtering by keyword, role, location, and pagination."""
    unique_actor = f"Actor{uuid.uuid4().hex[:6]}"
    await async_client.put(
        "/api/v1/users/me",
        headers=talent_headers,
        json={
            "full_name": f"{unique_actor} Singh",
            "role": "Action Hero",
            "location": "Hyderabad",
            "bio": "Martial artist and stunt performer.",
        },
    )

    # Search by keyword
    res_q = await async_client.get(f"/api/v1/users/search?q={unique_actor}")
    assert res_q.status_code == 200
    data_q = res_q.json()
    assert data_q["total"] >= 1
    assert any(unique_actor in u["full_name"] for u in data_q["items"])

    # Filter by role
    res_role = await async_client.get(f"/api/v1/users/search?role=Action Hero")
    assert res_role.status_code == 200
    assert any(u["role"] == "Action Hero" for u in res_role.json()["items"])

    # Filter by location
    res_loc = await async_client.get(f"/api/v1/users/search?location=Hyderabad")
    assert res_loc.status_code == 200
    assert any(u["location"] == "Hyderabad" for u in res_loc.json()["items"])

    # Pagination: limit
    res_paged = await async_client.get(f"/api/v1/users/search?q={unique_actor}&skip=0&limit=1")
    assert res_paged.status_code == 200
    assert len(res_paged.json()["items"]) <= 1


# ==============================================================================
# Entity-Specific Search: Production Houses
# ==============================================================================

@pytest.mark.asyncio
async def test_production_houses_search(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies production house search by company name, specialization, and location."""
    unique_ph = f"PhSearch{uuid.uuid4().hex[:6]}"
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={
            "company_name": f"{unique_ph} Entertainments",
            "description": "High budget regional cinema.",
            "location": "Chennai",
            "specialization": "VFX Production",
        },
    )

    # Search by company name keyword
    res_q = await async_client.get(f"/api/v1/production-houses/search?q={unique_ph}")
    assert res_q.status_code == 200
    items_q = res_q.json()
    assert len(items_q) >= 1
    assert any(unique_ph in p["company_name"] for p in items_q)

    # Filter by location
    res_loc = await async_client.get(f"/api/v1/production-houses/search?location=Chennai")
    assert res_loc.status_code == 200
    assert any(p["location"] == "Chennai" for p in res_loc.json())

    # Pagination
    res_paged = await async_client.get(f"/api/v1/production-houses/search?q={unique_ph}&skip=0&limit=1")
    assert res_paged.status_code == 200
    assert len(res_paged.json()) <= 1


# ==============================================================================
# Entity-Specific Search: Projects
# ==============================================================================

@pytest.mark.asyncio
async def test_projects_search(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies project search by title keyword, genre, and status."""
    unique_proj = f"ProjSearch{uuid.uuid4().hex[:6]}"
    # Ensure PH exists first
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": f"Studio for {unique_proj}"},
    )

    await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={
            "title": f"{unique_proj} The Movie",
            "description": "A psychological thriller about time loops.",
            "genre": "Psychological Thriller",
            "status": "pre-production",
        },
    )

    # Search by title keyword
    res_q = await async_client.get(f"/api/v1/projects/search?q={unique_proj}")
    assert res_q.status_code == 200
    items = res_q.json()
    assert len(items) >= 1
    assert any(unique_proj in p["title"] for p in items)

    # Filter by genre
    res_genre = await async_client.get(f"/api/v1/projects/search?genre=Psychological Thriller")
    assert res_genre.status_code == 200
    assert any(p["genre"] == "Psychological Thriller" for p in res_genre.json())

    # Filter by status
    res_status = await async_client.get(f"/api/v1/projects/search?status=pre-production")
    assert res_status.status_code == 200
    assert any(p["status"] == "pre-production" for p in res_status.json())


# ==============================================================================
# Entity-Specific Search: Opportunities
# ==============================================================================

@pytest.mark.asyncio
async def test_opportunities_search(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies opportunity search by title, role type, location, and status."""
    unique_opp = f"OppSearch{uuid.uuid4().hex[:6]}"
    # Setup PH and Project
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": f"Studio for {unique_opp}"},
    )
    proj_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": f"Project for {unique_opp}", "genre": "Drama"},
    )
    proj_id = proj_res.json()["id"]

    await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={
            "project_id": proj_id,
            "title": f"{unique_opp} Audition",
            "role_type": "Voice Artist",
            "requirements": "Fluent in Hindi and English.",
            "location": "Kolkata",
            "status": "open",
        },
    )

    # Search by keyword
    res_q = await async_client.get(f"/api/v1/opportunities/search?q={unique_opp}")
    assert res_q.status_code == 200
    items = res_q.json()
    assert len(items) >= 1
    assert any(unique_opp in o["title"] for o in items)

    # Filter by role_type
    res_role = await async_client.get(f"/api/v1/opportunities/search?role_type=Voice Artist")
    assert res_role.status_code == 200
    assert any(o["role_type"] == "Voice Artist" for o in res_role.json())

    # Filter by location
    res_loc = await async_client.get(f"/api/v1/opportunities/search?location=Kolkata")
    assert res_loc.status_code == 200
    assert any(o["location"] == "Kolkata" for o in res_loc.json())

    # Filter by status
    res_status = await async_client.get(f"/api/v1/opportunities/search?status=open")
    assert res_status.status_code == 200
    assert any(o["status"] == "open" for o in res_status.json())
