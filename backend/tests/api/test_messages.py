import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.message import Message
from app.models.social import Collaboration


# ==============================================================================
# Helper
# ==============================================================================

async def ensure_two_users(client: AsyncClient, h1: dict, h2: dict) -> tuple[UUID, UUID]:
    """Ensures both users exist in users table by syncing profiles via /me."""
    res1 = await client.get("/api/v1/users/me", headers=h1)
    res2 = await client.get("/api/v1/users/me", headers=h2)
    return UUID(res1.json()["id"]), UUID(res2.json()["id"])


# ==============================================================================
# Authentication & Validation Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_unauthenticated_message_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated message sending is rejected (401 or 403)."""
    payload = {"recipient_id": str(uuid.uuid4()), "body": "No auth message"}
    response = await async_client.post("/api/v1/messages/", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_message_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that invalid token is rejected (401 Unauthorized)."""
    payload = {"recipient_id": str(uuid.uuid4()), "body": "Invalid token message"}
    response = await async_client.post("/api/v1/messages/", headers=invalid_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_message_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token is rejected (401 Unauthorized)."""
    payload = {"recipient_id": str(uuid.uuid4()), "body": "Expired token message"}
    response = await async_client.post("/api/v1/messages/", headers=expired_headers, json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_cannot_message_self(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that a user cannot send a direct message to themselves (400 Bad Request)."""
    await async_client.get("/api/v1/users/me", headers=talent_headers)
    payload = {"recipient_id": str(talent_user_id), "body": "Self message"}
    response = await async_client.post("/api/v1/messages/", headers=talent_headers, json=payload)
    assert response.status_code == 400
    assert "cannot message yourself" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_message_nonexistent_recipient_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies sending message to non-existent recipient returns 404."""
    random_id = str(uuid.uuid4())
    payload = {"recipient_id": random_id, "body": "Ghost recipient message"}
    response = await async_client.post("/api/v1/messages/", headers=talent_headers, json=payload)
    assert response.status_code == 404
    assert "Recipient user not found" in response.json().get("detail", "")


# ==============================================================================
# Messaging Lifecycle, Threads & Read Status Persistence
# ==============================================================================

@pytest.mark.asyncio
async def test_send_message_and_verify_persistence(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies sending message, DB persistence of sender_id, recipient_id, body, and sent_at."""
    sender_id, recipient_id = await ensure_two_users(async_client, talent_headers, ph_headers)

    payload = {
        "recipient_id": str(recipient_id),
        "body": "Hello, I am interested in collaborating on your upcoming feature film.",
    }
    create_res = await async_client.post("/api/v1/messages/", headers=talent_headers, json=payload)
    assert create_res.status_code == 201
    data = create_res.json()
    assert data["sender_id"] == str(sender_id)
    assert data["recipient_id"] == str(recipient_id)
    assert data["body"] == payload["body"]
    assert data["is_read"] is False
    assert "id" in data
    assert "created_at" in data

    msg_id = UUID(data["id"])

    # Directly verify in database
    db_msg = (await test_db_session.execute(
        select(Message).where(Message.id == msg_id)
    )).scalar_one_or_none()
    assert db_msg is not None
    assert db_msg.sender_id == sender_id
    assert db_msg.recipient_id == recipient_id
    assert db_msg.body == payload["body"]
    assert db_msg.is_read is False
    assert db_msg.sent_at is not None
    assert db_msg.collaboration_id is None


@pytest.mark.asyncio
async def test_conversation_thread_and_automatic_mark_as_read(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies conversation thread retrieval and verifies automatic marking of unread messages as read."""
    t_id, ph_id = await ensure_two_users(async_client, talent_headers, ph_headers)

    # Talent sends 2 messages to PH
    await async_client.post(
        "/api/v1/messages/",
        headers=talent_headers,
        json={"recipient_id": str(ph_id), "body": "Message 1 from Talent"},
    )
    await async_client.post(
        "/api/v1/messages/",
        headers=talent_headers,
        json={"recipient_id": str(ph_id), "body": "Message 2 from Talent"},
    )

    # PH checks unread count: must be 2
    unread_res = await async_client.get("/api/v1/messages/unread-count", headers=ph_headers)
    assert unread_res.status_code == 200
    assert unread_res.json()["unread_count"] == 2

    # PH opens conversation thread with Talent
    thread_res = await async_client.get(f"/api/v1/messages/conversations/{t_id}", headers=ph_headers)
    assert thread_res.status_code == 200
    thread = thread_res.json()
    assert len(thread) == 2
    # Verify all messages marked as read
    assert all(m["is_read"] is True for m in thread)

    # PH checks unread count again: must be 0
    unread_after = await async_client.get("/api/v1/messages/unread-count", headers=ph_headers)
    assert unread_after.json()["unread_count"] == 0


@pytest.mark.asyncio
async def test_conversation_summaries(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
    talent2_headers: dict,
):
    """Verifies listing conversation summaries grouped by conversation partner."""
    t_id, ph_id = await ensure_two_users(async_client, talent_headers, ph_headers)
    _, t2_id = await ensure_two_users(async_client, talent_headers, talent2_headers)

    # Talent messages PH and Talent 2
    await async_client.post(
        "/api/v1/messages/",
        headers=talent_headers,
        json={"recipient_id": str(ph_id), "body": "Hi Producer!"},
    )
    await async_client.post(
        "/api/v1/messages/",
        headers=talent_headers,
        json={"recipient_id": str(t2_id), "body": "Hi Fellow Actor!"},
    )

    # Talent checks summaries
    summaries_res = await async_client.get("/api/v1/messages/conversations", headers=talent_headers)
    assert summaries_res.status_code == 200
    summaries = summaries_res.json()
    assert len(summaries) >= 2
    partner_ids = [s["user_id"] for s in summaries]
    assert str(ph_id) in partner_ids
    assert str(t2_id) in partner_ids


@pytest.mark.asyncio
async def test_get_and_delete_message(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies retrieving single message by ID and deleting a message."""
    _, ph_id = await ensure_two_users(async_client, talent_headers, ph_headers)

    send_res = await async_client.post(
        "/api/v1/messages/",
        headers=talent_headers,
        json={"recipient_id": str(ph_id), "body": "Ephemeral message to delete"},
    )
    msg_id = send_res.json()["id"]

    # Sender gets message
    get_res = await async_client.get(f"/api/v1/messages/{msg_id}", headers=talent_headers)
    assert get_res.status_code == 200
    assert get_res.json()["id"] == msg_id

    # Recipient also can get message
    rec_get = await async_client.get(f"/api/v1/messages/{msg_id}", headers=ph_headers)
    assert rec_get.status_code == 200

    # Sender deletes message
    del_res = await async_client.delete(f"/api/v1/messages/{msg_id}", headers=talent_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    verify_res = await async_client.get(f"/api/v1/messages/{msg_id}", headers=talent_headers)
    assert verify_res.status_code == 404


@pytest.mark.asyncio
async def test_message_with_collaboration_link(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies message linked to a valid collaboration record and DB relationship."""
    # 1. Create PH, Project, Collaboration
    await async_client.post("/api/v1/production-houses", headers=ph_headers, json={"company_name": "Msg PH"})
    proj_res = await async_client.post("/api/v1/projects", headers=ph_headers, json={"title": "Msg Project"})
    proj_id = proj_res.json()["id"]
    t_res = await async_client.get("/api/v1/users/me", headers=talent_headers)
    t_id = UUID(t_res.json()["id"])
    ph_user_res = await async_client.get("/api/v1/users/me", headers=ph_headers)
    ph_user_id = UUID(ph_user_res.json()["id"])

    collab_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": proj_id, "talent_id": str(t_id), "role": "Lead Actor"},
    )
    collab_id = UUID(collab_res.json()["id"])

    # 2. Insert message linked to this collaboration directly in DB
    db_msg = Message(
        sender_id=ph_user_id,
        recipient_id=t_id,
        collaboration_id=collab_id,
        body="Welcome to the collaboration! Let us discuss the script.",
        is_read=False,
    )
    test_db_session.add(db_msg)
    await test_db_session.flush()

    # Verify query and relation
    queried = (await test_db_session.execute(
        select(Message).options(selectinload(Message.collaboration)).where(Message.id == db_msg.id)
    )).scalar_one()
    assert queried.collaboration_id == collab_id
    assert queried.collaboration is not None
    assert queried.collaboration.role == "Lead Actor"


# ==============================================================================
# Cross-User Security Enforcement
# ==============================================================================

@pytest.mark.asyncio
async def test_third_party_cannot_view_or_delete_message(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
    talent2_headers: dict,
):
    """Verifies that an unrelated user (Talent 2) cannot view or delete a message between Talent 1 and PH."""
    _, ph_id = await ensure_two_users(async_client, talent_headers, ph_headers)
    await async_client.get("/api/v1/users/me", headers=talent2_headers)

    send_res = await async_client.post(
        "/api/v1/messages/",
        headers=talent_headers,
        json={"recipient_id": str(ph_id), "body": "Private business communication"},
    )
    msg_id = send_res.json()["id"]

    # Talent 2 attempts GET -> 403 Forbidden
    t2_get = await async_client.get(f"/api/v1/messages/{msg_id}", headers=talent2_headers)
    assert t2_get.status_code == 403
    assert "permission to view" in t2_get.json().get("detail", "")

    # Talent 2 attempts DELETE -> 403 Forbidden
    t2_del = await async_client.delete(f"/api/v1/messages/{msg_id}", headers=talent2_headers)
    assert t2_del.status_code == 403
    assert "permission to delete" in t2_del.json().get("detail", "")


@pytest.mark.asyncio
async def test_nonexistent_message_returns_404(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that non-existent message IDs return 404."""
    random_id = uuid.uuid4()
    get_res = await async_client.get(f"/api/v1/messages/{random_id}", headers=talent_headers)
    assert get_res.status_code == 404

    del_res = await async_client.delete(f"/api/v1/messages/{random_id}", headers=talent_headers)
    assert del_res.status_code == 404
