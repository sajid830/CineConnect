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


async def setup_accepted_collaboration(
    client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
) -> tuple[UUID, UUID, UUID]:
    """Sets up a PH, a project, invites talent, and talent accepts."""
    await client.post("/api/v1/production-houses", headers=ph_headers, json={"company_name": "Test Studio"})
    proj_res = await client.post("/api/v1/projects", headers=ph_headers, json={"title": "Test Production"})
    proj_id = proj_res.json()["id"]

    t_res = await client.get("/api/v1/users/me", headers=talent_headers)
    t_id = UUID(t_res.json()["id"])
    ph_res = await client.get("/api/v1/users/me", headers=ph_headers)
    ph_id = UUID(ph_res.json()["id"])

    # PH invites Talent
    collab_res = await client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": proj_id, "talent_id": str(t_id), "role": "Lead Actor"},
    )
    collab_id = collab_res.json()["id"]

    # Talent accepts invitation
    accept_res = await client.patch(
        f"/api/v1/collaborations/{collab_id}/accept",
        headers=talent_headers,
    )
    assert accept_res.status_code == 200

    return t_id, ph_id, UUID(collab_id)


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


@pytest.mark.asyncio
async def test_message_without_accepted_collaboration_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies that messaging without an accepted collaboration is forbidden (403)."""
    _, ph_id = await ensure_two_users(async_client, talent_headers, ph_headers)
    payload = {"recipient_id": str(ph_id), "body": "Unauthorized direct message"}
    res = await async_client.post("/api/v1/messages/", headers=talent_headers, json=payload)
    assert res.status_code == 403
    assert "accepted collaboration" in res.json().get("detail", "")


@pytest.mark.asyncio
async def test_message_with_only_invited_collaboration_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies that messaging when collaboration is still 'invited' (not yet accepted) is forbidden (403)."""
    await async_client.post("/api/v1/production-houses", headers=ph_headers, json={"company_name": "Invite Studio"})
    proj_res = await async_client.post("/api/v1/projects", headers=ph_headers, json={"title": "Invite Project"})
    proj_id = proj_res.json()["id"]

    t_res = await async_client.get("/api/v1/users/me", headers=talent_headers)
    t_id = t_res.json()["id"]

    # PH sends invite to Talent (status is 'invited')
    await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": proj_id, "talent_id": t_id, "role": "Actor"},
    )

    ph_res = await async_client.get("/api/v1/users/me", headers=ph_headers)
    ph_id = ph_res.json()["id"]

    # Talent tries to message PH before accepting -> 403 Forbidden
    res = await async_client.post(
        "/api/v1/messages/",
        headers=talent_headers,
        json={"recipient_id": ph_id, "body": "Premature message"},
    )
    assert res.status_code == 403
    assert "accepted collaboration" in res.json().get("detail", "")


@pytest.mark.asyncio
async def test_duplicate_message_prevention_idempotency(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies that repeated submissions with same client_message_id return the existing record without duplicates."""
    t_id, ph_id, _ = await setup_accepted_collaboration(async_client, talent_headers, ph_headers)

    client_id = f"test-client-{uuid.uuid4()}"
    payload = {
        "recipient_id": str(ph_id),
        "body": "First submission body",
        "client_message_id": client_id,
    }

    # 1. First submission -> 201 Created
    res1 = await async_client.post("/api/v1/messages/", headers=talent_headers, json=payload)
    assert res1.status_code == 201
    data1 = res1.json()
    assert data1["client_message_id"] == client_id
    msg_id = data1["id"]

    # 2. Resubmission with same client_message_id -> returns same message record
    res2 = await async_client.post("/api/v1/messages/", headers=talent_headers, json=payload)
    assert res2.status_code in (200, 201)
    data2 = res2.json()
    assert data2["id"] == msg_id
    assert data2["client_message_id"] == client_id

    # 3. Legitimate second message with identical text but different client_message_id -> creates second distinct message
    client_id_2 = f"test-client-{uuid.uuid4()}"
    payload2 = {
        "recipient_id": str(ph_id),
        "body": "First submission body",  # identical text
        "client_message_id": client_id_2,
    }
    res3 = await async_client.post("/api/v1/messages/", headers=talent_headers, json=payload2)
    assert res3.status_code == 201
    data3 = res3.json()
    assert data3["id"] != msg_id
    assert data3["client_message_id"] == client_id_2


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
    sender_id, recipient_id, collab_id = await setup_accepted_collaboration(async_client, talent_headers, ph_headers)

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
    assert db_msg.collaboration_id == collab_id


@pytest.mark.asyncio
async def test_conversation_thread_and_automatic_mark_as_read(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies conversation thread retrieval and verifies automatic marking of unread messages as read."""
    t_id, ph_id, _ = await setup_accepted_collaboration(async_client, talent_headers, ph_headers)

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
    t_id, ph_id, _ = await setup_accepted_collaboration(async_client, talent_headers, ph_headers)

    # Also invite and accept talent2 on the same project
    t2_res = await async_client.get("/api/v1/users/me", headers=talent2_headers)
    t2_id = t2_res.json()["id"]

    # PH creates project and invites talent2
    proj_res = await async_client.post("/api/v1/projects", headers=ph_headers, json={"title": "Second Project"})
    proj_id = proj_res.json()["id"]
    collab2_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": proj_id, "talent_id": t2_id, "role": "Supporting Actor"},
    )
    collab2_id = collab2_res.json()["id"]
    await async_client.patch(f"/api/v1/collaborations/{collab2_id}/accept", headers=talent2_headers)

    # PH messages Talent 1 and Talent 2
    await async_client.post(
        "/api/v1/messages/",
        headers=ph_headers,
        json={"recipient_id": str(t_id), "body": "Hi Talent 1!"},
    )
    await async_client.post(
        "/api/v1/messages/",
        headers=ph_headers,
        json={"recipient_id": str(t2_id), "body": "Hi Talent 2!"},
    )

    # PH checks summaries
    summaries_res = await async_client.get("/api/v1/messages/conversations", headers=ph_headers)
    assert summaries_res.status_code == 200
    summaries = summaries_res.json()
    assert len(summaries) >= 2
    partner_ids = [s["user_id"] for s in summaries]
    assert str(t_id) in partner_ids
    assert str(t2_id) in partner_ids


@pytest.mark.asyncio
async def test_get_and_delete_message(
    async_client: AsyncClient,
    talent_headers: dict,
    ph_headers: dict,
):
    """Verifies retrieving single message by ID and deleting a message."""
    _, ph_id, _ = await setup_accepted_collaboration(async_client, talent_headers, ph_headers)

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
    _, ph_id, _ = await setup_accepted_collaboration(async_client, talent_headers, ph_headers)
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
