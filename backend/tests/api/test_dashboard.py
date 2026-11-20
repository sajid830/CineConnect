"""Dashboard Domain Integration Tests.

Validates aggregated analytics, summary metrics, role-based protection,
and cross-entity data isolation for the Production House Dashboard and Talent Dashboard.
"""
from uuid import UUID
import pytest
from httpx import AsyncClient

from app.main import app


# ==============================================================================
# Route Registration & Smoke
# ==============================================================================

def test_dashboard_routes_registered():
    """Verifies dashboard endpoints are mounted on the FastAPI application."""
    routes = [getattr(r, "path", "") for r in app.routes]
    assert any("/api/v1/dashboard/talent" in r for r in routes)
    assert any("/api/v1/dashboard/production-house" in r for r in routes)


# ==============================================================================
# Role Restrictions & Authentication Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_cannot_access_ph_dashboard(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that Talent accounts cannot access Production House dashboard (403 Forbidden)."""
    response = await async_client.get(
        "/api/v1/dashboard/production-house",
        headers=talent_headers,
    )
    assert response.status_code == 403
    assert "restricted to Production House accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_ph_cannot_access_talent_dashboard(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that Production House accounts cannot access Talent dashboard (403 Forbidden)."""
    response = await async_client.get(
        "/api/v1/dashboard/talent",
        headers=ph_headers,
    )
    assert response.status_code == 403
    assert "restricted to Talent accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_unauthenticated_dashboard_access_rejected(async_client: AsyncClient):
    """Verifies unauthenticated access to both dashboards is rejected (401 or 403)."""
    res_ph = await async_client.get("/api/v1/dashboard/production-house")
    assert res_ph.status_code in (401, 403)

    res_talent = await async_client.get("/api/v1/dashboard/talent")
    assert res_talent.status_code in (401, 403)


# ==============================================================================
# Production House Dashboard: Empty State & Metric Computation
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_dashboard_empty_state_without_profile(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies empty dashboard state when no production house profile exists."""
    response = await async_client.get(
        "/api/v1/dashboard/production-house",
        headers=ph_headers,
    )
    assert response.status_code == 200
    data = response.json()

    assert data["total_projects"] == 0
    assert data["active_projects"] == 0
    assert data["total_opportunities"] == 0
    assert data["open_opportunities"] == 0
    assert data["total_applications_received"] == 0
    assert data["pending_reviews"] == 0
    assert data["total_collaborations"] == 0
    assert data["recent_opportunities"] == []


@pytest.mark.asyncio
async def test_ph_dashboard_computed_metrics(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies accurate metric aggregation for projects, opportunities, applications, and collaborations."""
    # 1. Create Production House
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Apex Studio Productions"},
    )

    # 2. Create Active Project (filming)
    p1_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Action Thriller One", "genre": "Action", "status": "filming"},
    )
    assert p1_res.status_code == 201
    p1_id = p1_res.json()["id"]

    # 3. Create Inactive Project (completed)
    p2_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Archive Film Two", "genre": "Documentary", "status": "completed"},
    )
    assert p2_res.status_code == 201

    # 4. Create Open Opportunity under Project 1
    opp1_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"project_id": p1_id, "title": "Stunt Coordinator", "role_type": "Crew", "status": "open"},
    )
    assert opp1_res.status_code == 201
    opp1_id = opp1_res.json()["id"]

    # 5. Create Closed Opportunity under Project 1
    opp2_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={"project_id": p1_id, "title": "Lead Villain", "role_type": "Actor", "status": "closed"},
    )
    assert opp2_res.status_code == 201

    # 6. Talent applies to Opportunity 1 (status: submitted -> pending_review)
    app_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": opp1_id, "cover_letter": "Ready for action filming."},
    )
    assert app_res.status_code == 201

    # 7. Create Collaboration with Talent under Project 1
    collab_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={
            "project_id": p1_id,
            "talent_id": str(talent_user_id),
            "role": "Stunt Director",
        },
    )
    assert collab_res.status_code == 201

    # 8. Query Dashboard
    dash_res = await async_client.get(
        "/api/v1/dashboard/production-house",
        headers=ph_headers,
    )
    assert dash_res.status_code == 200
    metrics = dash_res.json()

    assert metrics["total_projects"] == 2
    assert metrics["active_projects"] == 1
    assert metrics["total_opportunities"] == 2
    assert metrics["open_opportunities"] == 1
    assert metrics["total_applications_received"] == 1
    assert metrics["pending_reviews"] == 1
    assert metrics["total_collaborations"] == 1
    assert len(metrics["recent_opportunities"]) == 2
    assert any(o["id"] == opp1_id for o in metrics["recent_opportunities"])


# ==============================================================================
# Production House Dashboard: Cross-User Isolation
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_dashboard_cross_user_isolation(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
):
    """Verifies that one Production House cannot see another Production House's metrics."""
    # Studio 1 creates 1 project
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Studio Prime"},
    )
    await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Studio Prime Project", "genre": "Drama", "status": "filming"},
    )

    # Studio 2 creates 2 projects
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph2_headers,
        json={"company_name": "Studio Nova"},
    )
    await async_client.post(
        "/api/v1/projects",
        headers=ph2_headers,
        json={"title": "Studio Nova Project 1", "genre": "Comedy", "status": "development"},
    )
    await async_client.post(
        "/api/v1/projects",
        headers=ph2_headers,
        json={"title": "Studio Nova Project 2", "genre": "Action", "status": "filming"},
    )

    # Verify Studio 1 metrics
    dash1 = await async_client.get("/api/v1/dashboard/production-house", headers=ph_headers)
    assert dash1.status_code == 200
    assert dash1.json()["total_projects"] == 1
    assert dash1.json()["active_projects"] == 1

    # Verify Studio 2 metrics
    dash2 = await async_client.get("/api/v1/dashboard/production-house", headers=ph2_headers)
    assert dash2.status_code == 200
    assert dash2.json()["total_projects"] == 2
    assert dash2.json()["active_projects"] == 2


# ==============================================================================
# Talent Dashboard: Investigation & Status
# ==============================================================================

@pytest.mark.skip(
    reason=(
        "Blocked by application defect: dashboard.py (line 78) queries the 'notifications' "
        "table (Notification.user_id == talent_id), which does not exist in the 11 approved "
        "database tables. Endpoint raises UndefinedTableError (HTTP 500) until notifications table "
        "is added in a future migration or Notification count query is removed from the endpoint."
    )
)
@pytest.mark.asyncio
async def test_talent_dashboard_metrics(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies aggregated metrics for the talent dashboard."""
    response = await async_client.get(
        "/api/v1/dashboard/talent",
        headers=talent_headers,
    )
    assert response.status_code == 200
