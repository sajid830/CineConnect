import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import Interaction


# ==============================================================================
# Helper
# ==============================================================================

async def setup_post(client: AsyncClient, headers: dict) -> UUID:
    res = await client.post(
        "/api/v1/posts/",
        headers=headers,
        json={"caption": "Post for interactions test"},
    )
    assert res.status_code == 201
    return UUID(res.json()["id"])


# ==============================================================================
# Authentication & Validation Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_unauthenticated_interaction_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated interaction creation is rejected (401 or 403)."""
    payload = {"post_id": str(uuid.uuid4()), "type": "like"}
    response = await async_client.post("/api/v1/interactions/", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_interaction_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that invalid token is rejected (401 Unauthorized)."""
    payload = {"post_id": str(uuid.uuid4()), "type": "like"}
    response = await async_client.post("/api/v1/interactions/", headers=invalid_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_interaction_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token is rejected (401 Unauthorized)."""
    payload = {"post_id": str(uuid.uuid4()), "type": "like"}
    response = await async_client.post("/api/v1/interactions/", headers=expired_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_interaction_on_nonexistent_post_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that attempting to interact with a non-existent post returns 404."""
    random_id = str(uuid.uuid4())
    payload = {"post_id": random_id, "type": "like"}
    response = await async_client.post("/api/v1/interactions/", headers=talent_headers, json=payload)
    assert response.status_code == 404
    assert "Post not found" in response.json().get("detail", "")


# ==============================================================================
# Interactions Lifecycle (Likes & Comments)
# ==============================================================================

@pytest.mark.asyncio
async def test_like_a_post_and_retrieve_persistence(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies liking a post, DB persistence, and listing interactions on the post."""
    post_id = await setup_post(async_client, talent_headers)

    payload = {
        "post_id": str(post_id),
        "type": "like",
    }
    create_res = await async_client.post("/api/v1/interactions/", headers=talent_headers, json=payload)
    assert create_res.status_code == 201
    data = create_res.json()
    assert data["post_id"] == str(post_id)
    assert data["user_id"] == str(talent_user_id)
    assert data["type"] == "like"
    assert "id" in data

    interaction_id = UUID(data["id"])

    # Verify directly in DB
    db_item = (await test_db_session.execute(
        select(Interaction).where(Interaction.id == interaction_id)
    )).scalar_one_or_none()
    assert db_item is not None
    assert db_item.post_id == post_id
    assert db_item.user_id == talent_user_id
    assert db_item.type == "like"

    # Verify via GET /api/v1/posts/{post_id}/interactions?type=like
    list_res = await async_client.get(f"/api/v1/posts/{post_id}/interactions?type=like")
    assert list_res.status_code == 200
    likes = list_res.json()
    assert len(likes) >= 1
    assert any(l["id"] == str(interaction_id) for l in likes)


@pytest.mark.asyncio
async def test_unlike_post(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies unliking a post by deleting the like interaction."""
    post_id = await setup_post(async_client, talent_headers)

    like_res = await async_client.post(
        "/api/v1/interactions/",
        headers=talent_headers,
        json={"post_id": str(post_id), "type": "like"},
    )
    like_id = like_res.json()["id"]

    # Delete like
    del_res = await async_client.delete(f"/api/v1/interactions/{like_id}", headers=talent_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/interactions/{like_id}")
    assert get_res.status_code == 404


@pytest.mark.asyncio
async def test_add_and_update_comment_on_post(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies adding a comment to a post and editing the comment."""
    post_id = await setup_post(async_client, talent_headers)

    # Talent 2 comments on Talent 1's post
    comment_payload = {
        "post_id": str(post_id),
        "type": "comment",
        "comment": "Outstanding cinematography! Which camera did you use?",
    }
    comment_res = await async_client.post(
        "/api/v1/interactions/",
        headers=talent2_headers,
        json=comment_payload,
    )
    assert comment_res.status_code == 201
    comment_data = comment_res.json()
    assert comment_data["type"] == "comment"
    assert comment_data["comment"] == comment_payload["comment"]
    comment_id = comment_data["id"]

    # Update comment text
    patch_res = await async_client.patch(
        f"/api/v1/interactions/{comment_id}",
        headers=talent2_headers,
        json={"comment": "Outstanding cinematography! Was it shot on Alexa Mini LF?"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["comment"] == "Outstanding cinematography! Was it shot on Alexa Mini LF?"

    # Verify via /api/v1/posts/{post_id}/interactions?type=comment
    list_comments = await async_client.get(f"/api/v1/posts/{post_id}/interactions?type=comment")
    assert list_comments.status_code == 200
    assert any(c["id"] == comment_id for c in list_comments.json())


@pytest.mark.asyncio
async def test_create_interaction_via_post_subroute(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies creating an interaction using the subroute POST /api/v1/posts/{post_id}/interactions."""
    post_id = await setup_post(async_client, talent_headers)

    res = await async_client.post(
        f"/api/v1/posts/{post_id}/interactions?type=comment",
        headers=talent_headers,
        json={"comment": "Comment via post subroute"},
    )
    assert res.status_code == 201
    assert res.json()["post_id"] == str(post_id)
    assert res.json()["comment"] == "Comment via post subroute"


@pytest.mark.asyncio
async def test_list_own_interactions(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies retrieving user's own interactions list via GET /api/v1/interactions/my."""
    post_id = await setup_post(async_client, talent_headers)

    await async_client.post(
        "/api/v1/interactions/",
        headers=talent_headers,
        json={"post_id": str(post_id), "type": "like"},
    )

    my_res = await async_client.get("/api/v1/interactions/my", headers=talent_headers)
    assert my_res.status_code == 200
    my_interactions = my_res.json()
    assert len(my_interactions) >= 1
    assert any(i["post_id"] == str(post_id) for i in my_interactions)


# ==============================================================================
# Cross-User Ownership Enforcement
# ==============================================================================

@pytest.mark.asyncio
async def test_another_user_cannot_edit_or_delete_interaction(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies that Talent 2 cannot update or delete Talent 1's comment/like (404 Not Found / ownership filter)."""
    post_id = await setup_post(async_client, talent_headers)

    create_res = await async_client.post(
        "/api/v1/interactions/",
        headers=talent_headers,
        json={"post_id": str(post_id), "type": "comment", "comment": "Talent 1 private opinion"},
    )
    interaction_id = create_res.json()["id"]

    # Talent 2 attempts to edit
    t2_patch = await async_client.patch(
        f"/api/v1/interactions/{interaction_id}",
        headers=talent2_headers,
        json={"comment": "Hacked comment text"},
    )
    assert t2_patch.status_code == 404
    assert "permission to edit" in t2_patch.json().get("detail", "")

    # Talent 2 attempts to delete
    t2_del = await async_client.delete(
        f"/api/v1/interactions/{interaction_id}",
        headers=talent2_headers,
    )
    assert t2_del.status_code == 404
    assert "permission to delete" in t2_del.json().get("detail", "")

    # Comment remains untouched
    get_res = await async_client.get(f"/api/v1/interactions/{interaction_id}")
    assert get_res.status_code == 200
    assert get_res.json()["comment"] == "Talent 1 private opinion"


@pytest.mark.asyncio
async def test_nonexistent_interaction_returns_404(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies operations on non-existent interaction IDs return 404."""
    random_id = uuid.uuid4()

    get_res = await async_client.get(f"/api/v1/interactions/{random_id}")
    assert get_res.status_code == 404

    patch_res = await async_client.patch(
        f"/api/v1/interactions/{random_id}",
        headers=talent_headers,
        json={"comment": "Ghost update"},
    )
    assert patch_res.status_code == 404

    del_res = await async_client.delete(f"/api/v1/interactions/{random_id}", headers=talent_headers)
    assert del_res.status_code == 404
