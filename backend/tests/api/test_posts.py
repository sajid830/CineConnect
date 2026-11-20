import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import Post


# ==============================================================================
# Authentication & Validation Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_unauthenticated_post_creation_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated post creation is rejected (401 or 403)."""
    payload = {"caption": "No auth post"}
    response = await async_client.post("/api/v1/posts/", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_post_creation_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that malformed JWT token is rejected (401 Unauthorized)."""
    payload = {"caption": "Invalid token post"}
    response = await async_client.post("/api/v1/posts/", headers=invalid_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_post_creation_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired JWT token is rejected (401 Unauthorized)."""
    payload = {"caption": "Expired token post"}
    response = await async_client.post("/api/v1/posts/", headers=expired_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_post_with_empty_or_invalid_payload_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that creating a post without mandatory caption field returns 422 Unprocessable Entity."""
    # Missing caption
    response = await async_client.post(
        "/api/v1/posts/",
        headers=talent_headers,
        json={"media_url": "https://cdn.cineconnect.com/posts/pic.jpg"},
    )
    assert response.status_code == 422


# ==============================================================================
# Post Lifecycle (CRUD) & Persistence Verification
# ==============================================================================

@pytest.mark.asyncio
async def test_create_and_retrieve_post_persistence(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies creating a post, DB persistence of caption and media_url, and retrieval by ID."""
    payload = {
        "caption": "Just wrapped up Day 14 on our indie thriller feature film! Amazing crew.",
        "media_url": "https://cdn.cineconnect.com/posts/bts-day14.jpg",
    }
    create_res = await async_client.post(
        "/api/v1/posts/",
        headers=talent_headers,
        json=payload,
    )
    assert create_res.status_code == 201
    data = create_res.json()
    assert data["caption"] == payload["caption"]
    assert data["media_url"] == payload["media_url"]
    assert data["user_id"] == str(talent_user_id)
    assert "id" in data
    assert "created_at" in data

    post_id = UUID(data["id"])

    # Directly verify in PostgreSQL database
    db_post = (await test_db_session.execute(
        select(Post).where(Post.id == post_id)
    )).scalar_one_or_none()
    assert db_post is not None
    assert db_post.user_id == talent_user_id
    assert db_post.caption == payload["caption"]
    assert db_post.media_url == payload["media_url"]

    # Public retrieval by ID
    get_res = await async_client.get(f"/api/v1/posts/{post_id}")
    assert get_res.status_code == 200
    retrieved = get_res.json()
    assert retrieved["id"] == str(post_id)
    assert retrieved["caption"] == payload["caption"]


@pytest.mark.asyncio
async def test_ph_user_can_also_create_post(
    async_client: AsyncClient,
    ph_headers: dict,
    ph_user_id: UUID,
):
    """Verifies that Production House users can also publish feed posts."""
    payload = {
        "caption": "Official Announcement: Principal photography begins next month!",
        "media_url": "https://cdn.cineconnect.com/posts/announcement.jpg",
    }
    response = await async_client.post("/api/v1/posts/", headers=ph_headers, json=payload)
    assert response.status_code == 201
    assert response.json()["user_id"] == str(ph_user_id)


@pytest.mark.asyncio
async def test_retrieve_feed_and_own_posts(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies retrieving public feed and listing own posts."""
    # Post from talent
    await async_client.post("/api/v1/posts/", headers=talent_headers, json={"caption": "Talent Feed Post 1"})
    # Post from PH
    await async_client.post("/api/v1/posts/", headers=ph_headers, json={"caption": "PH Feed Post 2"})

    # Public feed
    feed_res = await async_client.get("/api/v1/posts/")
    assert feed_res.status_code == 200
    feed = feed_res.json()
    assert len(feed) >= 2

    # Own posts
    my_res = await async_client.get("/api/v1/posts/my", headers=talent_headers)
    assert my_res.status_code == 200
    my_posts = my_res.json()
    assert any(p["caption"] == "Talent Feed Post 1" for p in my_posts)
    assert not any(p["caption"] == "PH Feed Post 2" for p in my_posts)


@pytest.mark.asyncio
async def test_list_posts_by_specific_user(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
    talent2_headers: dict,
):
    """Verifies retrieving posts authored by a specific user via GET /api/v1/users/{user_id}/posts."""
    await async_client.post(
        "/api/v1/posts/",
        headers=talent_headers,
        json={"caption": "Specific User Public Post"},
    )

    user_posts_res = await async_client.get(
        f"/api/v1/users/{talent_user_id}/posts",
        headers=talent2_headers,
    )
    assert user_posts_res.status_code == 200
    posts = user_posts_res.json()
    assert len(posts) >= 1
    assert any(p["caption"] == "Specific User Public Post" for p in posts)


@pytest.mark.asyncio
async def test_update_own_post(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies owner can update post caption and media URL."""
    create_res = await async_client.post(
        "/api/v1/posts/",
        headers=talent_headers,
        json={"caption": "Draft caption"},
    )
    post_id = create_res.json()["id"]

    update_payload = {
        "caption": "Polished and final caption with proper credits.",
        "media_url": "https://cdn.cineconnect.com/posts/final.jpg",
    }
    update_res = await async_client.put(
        f"/api/v1/posts/{post_id}",
        headers=talent_headers,
        json=update_payload,
    )
    assert update_res.status_code == 200
    updated = update_res.json()
    assert updated["caption"] == update_payload["caption"]
    assert updated["media_url"] == update_payload["media_url"]


@pytest.mark.asyncio
async def test_delete_own_post(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies owner can delete their post."""
    create_res = await async_client.post(
        "/api/v1/posts/",
        headers=talent_headers,
        json={"caption": "Temporary Announcement to delete"},
    )
    post_id = create_res.json()["id"]

    del_res = await async_client.delete(f"/api/v1/posts/{post_id}", headers=talent_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/posts/{post_id}")
    assert get_res.status_code == 404


# ==============================================================================
# Cross-User Ownership & Error Conditions
# ==============================================================================

@pytest.mark.asyncio
async def test_another_user_cannot_update_or_delete_post(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies that Talent 2 cannot update or delete Talent 1's post (404 Not Found / ownership filter)."""
    create_res = await async_client.post(
        "/api/v1/posts/",
        headers=talent_headers,
        json={"caption": "Talent 1 Original Post"},
    )
    post_id = create_res.json()["id"]

    # Talent 2 attempts update
    t2_put = await async_client.put(
        f"/api/v1/posts/{post_id}",
        headers=talent2_headers,
        json={"caption": "Hijacked Caption"},
    )
    assert t2_put.status_code == 404
    assert "permission to edit" in t2_put.json().get("detail", "")

    # Talent 2 attempts delete
    t2_del = await async_client.delete(
        f"/api/v1/posts/{post_id}",
        headers=talent2_headers,
    )
    assert t2_del.status_code == 404
    assert "permission to delete" in t2_del.json().get("detail", "")

    # Post must remain intact
    verify_res = await async_client.get(f"/api/v1/posts/{post_id}")
    assert verify_res.status_code == 200
    assert verify_res.json()["caption"] == "Talent 1 Original Post"


@pytest.mark.asyncio
async def test_nonexistent_post_id_returns_404(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that operations on non-existent post IDs return 404."""
    random_id = uuid.uuid4()

    get_res = await async_client.get(f"/api/v1/posts/{random_id}")
    assert get_res.status_code == 404

    put_res = await async_client.put(
        f"/api/v1/posts/{random_id}",
        headers=talent_headers,
        json={"caption": "Ghost Post Update"},
    )
    assert put_res.status_code == 404

    del_res = await async_client.delete(f"/api/v1/posts/{random_id}", headers=talent_headers)
    assert del_res.status_code == 404
