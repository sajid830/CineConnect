import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.portfolio import PortfolioMedia


# ==============================================================================
# Role Restrictions & Authentication Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_cannot_create_portfolio_item(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that Production House accounts cannot create portfolio items (403 Forbidden)."""
    payload = {
        "title": "Unauthorized PH Reel",
        "media_type": "video",
        "media_url": "https://cdn.example.com/ph_reel.mp4",
    }
    response = await async_client.post(
        "/api/v1/portfolio/",
        headers=ph_headers,
        json=payload,
    )
    assert response.status_code == 403
    assert "restricted to Talent accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_unauthenticated_portfolio_access_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated access to portfolio creation/my is rejected (401 or 403)."""
    post_res = await async_client.post(
        "/api/v1/portfolio/",
        json={"title": "No Auth", "media_url": "https://example.com/item.mp4"},
    )
    assert post_res.status_code in (401, 403)

    my_res = await async_client.get("/api/v1/portfolio/my")
    assert my_res.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_portfolio_access_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that invalid token is rejected (401 Unauthorized)."""
    response = await async_client.post(
        "/api/v1/portfolio/",
        headers=invalid_headers,
        json={"title": "Invalid Token", "media_url": "https://example.com/item.mp4"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_portfolio_access_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token is rejected (401 Unauthorized)."""
    response = await async_client.post(
        "/api/v1/portfolio/",
        headers=expired_headers,
        json={"title": "Expired Token", "media_url": "https://example.com/item.mp4"},
    )
    assert response.status_code == 401


# ==============================================================================
# Portfolio Media Lifecycle (CRUD)
# ==============================================================================

@pytest.mark.asyncio
async def test_create_and_retrieve_portfolio_item(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies creating portfolio item and verifies DB persistence and talent_id."""
    payload = {
        "title": "Lead Monologue Dramatic Reel",
        "description": "Shakespearean and modern dramatic monologues recorded in studio.",
        "media_type": "video",
        "media_url": "https://cdn.cineconnect.com/reels/monologue.mp4",
        "thumbnail_url": "https://cdn.cineconnect.com/reels/thumb.jpg",
    }
    create_res = await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json=payload,
    )
    assert create_res.status_code == 201
    data = create_res.json()
    assert data["title"] == payload["title"]
    assert data["description"] == payload["description"]
    assert data["media_type"] == "video"
    assert data["media_url"] == payload["media_url"]
    assert data["thumbnail_url"] == payload["thumbnail_url"]
    assert data["user_id"] == str(talent_user_id)
    assert "id" in data
    assert "created_at" in data

    media_id = UUID(data["id"])

    # Verify directly via database query to check talent_id foreign key
    db_item = (await test_db_session.execute(
        select(PortfolioMedia).where(PortfolioMedia.id == media_id)
    )).scalar_one_or_none()
    assert db_item is not None
    assert db_item.talent_id == talent_user_id
    assert db_item.title == payload["title"]

    # Retrieve by ID (public access)
    get_res = await async_client.get(f"/api/v1/portfolio/{media_id}")
    assert get_res.status_code == 200
    retrieved = get_res.json()
    assert retrieved["id"] == str(media_id)
    assert retrieved["title"] == payload["title"]


@pytest.mark.asyncio
async def test_list_own_portfolio(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies talent can list their portfolio assets."""
    await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json={"title": "Action Stunt Clip", "media_url": "https://cdn.example.com/stunt.mp4", "media_type": "video"},
    )
    await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json={"title": "Headshot 2026", "media_url": "https://cdn.example.com/headshot.jpg", "media_type": "image"},
    )

    my_res = await async_client.get("/api/v1/portfolio/my", headers=talent_headers)
    assert my_res.status_code == 200
    items = my_res.json()
    assert len(items) == 2
    titles = [i["title"] for i in items]
    assert "Action Stunt Clip" in titles
    assert "Headshot 2026" in titles


@pytest.mark.asyncio
async def test_retrieve_another_users_public_portfolio(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
    talent2_headers: dict,
):
    """Verifies that another user can view talent's public portfolio via GET /api/v1/users/{user_id}/portfolio."""
    await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json={"title": "Talent 1 Public Reel", "media_url": "https://cdn.example.com/t1.mp4", "media_type": "video"},
    )

    # Talent 2 fetches Talent 1's portfolio
    pub_res = await async_client.get(
        f"/api/v1/users/{talent_user_id}/portfolio",
        headers=talent2_headers,
    )
    assert pub_res.status_code == 200
    items = pub_res.json()
    assert len(items) >= 1
    assert any(i["title"] == "Talent 1 Public Reel" for i in items)


@pytest.mark.asyncio
async def test_update_portfolio_item(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies updating portfolio media fields."""
    create_res = await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json={"title": "Draft Item", "media_url": "https://cdn.example.com/draft.mp4", "media_type": "video"},
    )
    media_id = create_res.json()["id"]

    update_payload = {
        "title": "Polished Festival Reel",
        "description": "Updated color graded 4K showreel.",
        "media_type": "video",
        "media_url": "https://cdn.example.com/final_4k.mp4",
        "thumbnail_url": "https://cdn.example.com/final_thumb.jpg",
    }
    update_res = await async_client.put(
        f"/api/v1/portfolio/{media_id}",
        headers=talent_headers,
        json=update_payload,
    )
    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["title"] == "Polished Festival Reel"
    assert updated_data["description"] == "Updated color graded 4K showreel."
    assert updated_data["media_url"] == "https://cdn.example.com/final_4k.mp4"


@pytest.mark.asyncio
async def test_delete_portfolio_item(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies deleting portfolio item removes it."""
    create_res = await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json={"title": "To Delete", "media_url": "https://cdn.example.com/del.mp4", "media_type": "video"},
    )
    media_id = create_res.json()["id"]

    del_res = await async_client.delete(f"/api/v1/portfolio/{media_id}", headers=talent_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/portfolio/{media_id}")
    assert get_res.status_code == 404


# ==============================================================================
# Cross-User Ownership & Error Conditions
# ==============================================================================

@pytest.mark.asyncio
async def test_another_talent_cannot_edit_or_delete_portfolio_item(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies that Talent 2 cannot update or delete Talent 1's portfolio item (404 Not Found / Ownership filter)."""
    create_res = await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json={"title": "Talent 1 Exclusive Reel", "media_url": "https://cdn.example.com/t1.mp4", "media_type": "video"},
    )
    media_id = create_res.json()["id"]

    # Talent 2 attempts PUT update
    t2_put = await async_client.put(
        f"/api/v1/portfolio/{media_id}",
        headers=talent2_headers,
        json={"title": "Hijacked Item", "media_url": "https://cdn.example.com/hacked.mp4", "media_type": "video"},
    )
    assert t2_put.status_code == 404
    assert "permission to edit" in t2_put.json().get("detail", "")

    # Talent 2 attempts DELETE
    t2_del = await async_client.delete(
        f"/api/v1/portfolio/{media_id}",
        headers=talent2_headers,
    )
    assert t2_del.status_code == 404
    assert "permission to delete" in t2_del.json().get("detail", "")

    # Item should still exist
    get_res = await async_client.get(f"/api/v1/portfolio/{media_id}")
    assert get_res.status_code == 200
    assert get_res.json()["title"] == "Talent 1 Exclusive Reel"


@pytest.mark.asyncio
async def test_nonexistent_portfolio_id_returns_404(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies operations on non-existent media IDs return 404."""
    random_id = uuid.uuid4()

    get_res = await async_client.get(f"/api/v1/portfolio/{random_id}")
    assert get_res.status_code == 404

    put_res = await async_client.put(
        f"/api/v1/portfolio/{random_id}",
        headers=talent_headers,
        json={"title": "Ghost", "media_url": "https://example.com/ghost.mp4", "media_type": "video"},
    )
    assert put_res.status_code == 404

    del_res = await async_client.delete(f"/api/v1/portfolio/{random_id}", headers=talent_headers)
    assert del_res.status_code == 404
