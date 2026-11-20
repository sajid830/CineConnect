import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import Connection


# ==============================================================================
# Authentication & Validation Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_unauthenticated_connection_request_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated connection request is rejected (401 or 403)."""
    payload = {"receiver_id": str(uuid.uuid4())}
    response = await async_client.post("/api/v1/connections/", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_connection_request_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that malformed token is rejected (401 Unauthorized)."""
    payload = {"receiver_id": str(uuid.uuid4())}
    response = await async_client.post("/api/v1/connections/", headers=invalid_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_connection_request_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token is rejected (401 Unauthorized)."""
    payload = {"receiver_id": str(uuid.uuid4())}
    response = await async_client.post("/api/v1/connections/", headers=expired_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_self_connection_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that a user cannot connect with themselves (400 Bad Request)."""
    payload = {"receiver_id": str(talent_user_id)}
    response = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 400
    assert "cannot connect with yourself" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_connect_to_nonexistent_user_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that connecting to a non-existent user returns 404."""
    random_id = str(uuid.uuid4())
    payload = {"receiver_id": random_id}
    response = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 404
    assert "Target user not found" in response.json().get("detail", "")


# ==============================================================================
# Connection Lifecycle & Status Management
# ==============================================================================

@pytest.mark.asyncio
async def test_send_connection_request_and_verify_persistence(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    talent_headers: dict,
    talent_user_id: UUID,
    talent2_headers: dict,
    talent2_user_id: UUID,
):
    """Verifies sending connection request, initial 'pending' status, and DB persistence."""
    # Ensure receiver user exists in DB
    await async_client.get("/api/v1/users/me", headers=talent2_headers)

    payload = {"receiver_id": str(talent2_user_id)}
    create_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json=payload,
    )
    assert create_res.status_code == 201
    data = create_res.json()
    assert data["sender_id"] == str(talent_user_id)
    assert data["receiver_id"] == str(talent2_user_id)
    assert data["status"] == "pending"
    assert "id" in data

    conn_id = UUID(data["id"])

    # Verify directly in PostgreSQL
    db_conn = (await test_db_session.execute(
        select(Connection).where(Connection.id == conn_id)
    )).scalar_one_or_none()
    assert db_conn is not None
    assert db_conn.follower_id == talent_user_id
    assert db_conn.following_id == talent2_user_id
    assert db_conn.status == "pending"

    # Receiver inspects pending requests
    pending_res = await async_client.get("/api/v1/connections/requests", headers=talent2_headers)
    assert pending_res.status_code == 200
    pending_list = pending_res.json()
    assert len(pending_list) >= 1
    assert any(c["id"] == str(conn_id) for c in pending_list)


@pytest.mark.asyncio
async def test_accept_connection_request(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
    talent2_headers: dict,
    talent2_user_id: UUID,
):
    """Verifies receiver accepts request, status changes to 'accepted', and appears in connections/followers."""
    await async_client.get("/api/v1/users/me", headers=talent2_headers)

    create_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json={"receiver_id": str(talent2_user_id)},
    )
    conn_id = create_res.json()["id"]

    # Receiver accepts
    accept_res = await async_client.patch(
        f"/api/v1/connections/{conn_id}/accept",
        headers=talent2_headers,
    )
    assert accept_res.status_code == 200
    assert accept_res.json()["status"] == "accepted"

    # Listed in accepted connections
    my_conn = await async_client.get("/api/v1/connections/my", headers=talent_headers)
    assert my_conn.status_code == 200
    assert any(c["id"] == conn_id for c in my_conn.json())

    # Listed in public followers/following
    followers_res = await async_client.get(f"/api/v1/users/{talent2_user_id}/followers")
    assert followers_res.status_code == 200
    assert any(c["id"] == conn_id for c in followers_res.json())

    following_res = await async_client.get(f"/api/v1/users/{talent_user_id}/following")
    assert following_res.status_code == 200
    assert any(c["id"] == conn_id for c in following_res.json())


@pytest.mark.asyncio
async def test_reject_connection_request(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
    talent2_user_id: UUID,
):
    """Verifies receiver can reject a connection request."""
    await async_client.get("/api/v1/users/me", headers=talent2_headers)

    create_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json={"receiver_id": str(talent2_user_id)},
    )
    conn_id = create_res.json()["id"]

    # Receiver rejects
    reject_res = await async_client.patch(
        f"/api/v1/connections/{conn_id}/reject",
        headers=talent2_headers,
    )
    assert reject_res.status_code == 200
    assert reject_res.json()["status"] == "rejected"

    # Not in accepted connections
    my_conn = await async_client.get("/api/v1/connections/my", headers=talent_headers)
    assert my_conn.status_code == 200
    assert not any(c["id"] == conn_id for c in my_conn.json())


@pytest.mark.asyncio
async def test_unfollow_and_remove_connection(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
    talent2_user_id: UUID,
):
    """Verifies either party can delete an existing connection / unfollow."""
    await async_client.get("/api/v1/users/me", headers=talent2_headers)

    create_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json={"receiver_id": str(talent2_user_id)},
    )
    conn_id = create_res.json()["id"]

    # Sender removes / cancels request
    del_res = await async_client.delete(f"/api/v1/connections/{conn_id}", headers=talent_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/connections/{conn_id}", headers=talent_headers)
    assert get_res.status_code == 404


# ==============================================================================
# Uniqueness & Cross-User Security Enforcement
# ==============================================================================

@pytest.mark.asyncio
async def test_prevent_duplicate_connection_request(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
    talent2_user_id: UUID,
):
    """Verifies that duplicate connection requests between the same pair return 409 Conflict."""
    await async_client.get("/api/v1/users/me", headers=talent2_headers)

    first_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json={"receiver_id": str(talent2_user_id)},
    )
    assert first_res.status_code == 201

    # Second attempt (same direction)
    dup_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json={"receiver_id": str(talent2_user_id)},
    )
    assert dup_res.status_code == 409
    assert "already exists" in dup_res.json().get("detail", "")

    # Reverse direction attempt
    reverse_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent2_headers,
        json={"receiver_id": str(dup_res.json())},  # will fail with 409 if valid UUID passed
    )
    # Testing reverse attempt with Talent 1 as receiver
    reverse_proper = await async_client.post(
        "/api/v1/connections/",
        headers=talent2_headers,
        json={"receiver_id": first_res.json()["sender_id"]},
    )
    assert reverse_proper.status_code == 409
    assert "already exists" in reverse_proper.json().get("detail", "")


@pytest.mark.asyncio
async def test_cross_user_connection_authorization(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
    talent2_user_id: UUID,
    ph_headers: dict,
):
    """Verifies that a third party (PH) cannot view, accept, reject, or delete Talent 1 & 2's connection."""
    await async_client.get("/api/v1/users/me", headers=talent2_headers)

    create_res = await async_client.post(
        "/api/v1/connections/",
        headers=talent_headers,
        json={"receiver_id": str(talent2_user_id)},
    )
    conn_id = create_res.json()["id"]

    # Third party attempts GET -> 403 Forbidden
    ph_get = await async_client.get(f"/api/v1/connections/{conn_id}", headers=ph_headers)
    assert ph_get.status_code == 403
    assert "permission to view" in ph_get.json().get("detail", "")

    # Third party attempts accept -> 404 (receiver only filter)
    ph_accept = await async_client.patch(f"/api/v1/connections/{conn_id}/accept", headers=ph_headers)
    assert ph_accept.status_code == 404

    # Third party attempts reject -> 404
    ph_reject = await async_client.patch(f"/api/v1/connections/{conn_id}/reject", headers=ph_headers)
    assert ph_reject.status_code == 404

    # Third party attempts delete -> 404
    ph_del = await async_client.delete(f"/api/v1/connections/{conn_id}", headers=ph_headers)
    assert ph_del.status_code == 404


@pytest.mark.asyncio
async def test_nonexistent_connection_id_returns_404(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that non-existent connection IDs return 404."""
    random_id = uuid.uuid4()

    get_res = await async_client.get(f"/api/v1/connections/{random_id}", headers=talent_headers)
    assert get_res.status_code == 404

    accept_res = await async_client.patch(f"/api/v1/connections/{random_id}/accept", headers=talent_headers)
    assert accept_res.status_code == 404

    del_res = await async_client.delete(f"/api/v1/connections/{random_id}", headers=talent_headers)
    assert del_res.status_code == 404
