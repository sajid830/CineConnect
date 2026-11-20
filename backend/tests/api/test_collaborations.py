import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import Collaboration


# ==============================================================================
# Helper
# ==============================================================================

async def setup_project_and_talent(
    client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
) -> tuple[UUID, UUID, UUID]:
    """Sets up a production house, project, and ensures talent user exists."""
    ph_res = await client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Collab Pictures Studio", "location": "Mumbai"},
    )
    assert ph_res.status_code == 201
    ph_id = UUID(ph_res.json()["id"])

    proj_res = await client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Collab Project Alpha", "genre": "Drama"},
    )
    assert proj_res.status_code == 201
    proj_id = UUID(proj_res.json()["id"])

    # Ensure talent exists
    talent_res = await client.get("/api/v1/users/me", headers=talent_headers)
    assert talent_res.status_code == 200
    talent_id = UUID(talent_res.json()["id"])

    return ph_id, proj_id, talent_id


# ==============================================================================
# Role Restrictions & Authentication Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_cannot_create_collaboration(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies that a Talent account cannot create collaboration invitations (403 Forbidden)."""
    payload = {
        "project_id": str(uuid.uuid4()),
        "talent_id": str(uuid.uuid4()),
        "role": "Director",
    }
    response = await async_client.post(
        "/api/v1/collaborations/",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 403
    assert "restricted to Production House accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_unauthenticated_collaboration_creation_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated request to create collaboration is rejected (401 or 403)."""
    payload = {"project_id": str(uuid.uuid4()), "talent_id": str(uuid.uuid4())}
    response = await async_client.post("/api/v1/collaborations/", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_collaboration_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that invalid token is rejected (401 Unauthorized)."""
    payload = {"project_id": str(uuid.uuid4()), "talent_id": str(uuid.uuid4())}
    response = await async_client.post(
        "/api/v1/collaborations/",
        headers=invalid_headers,
        json=payload,
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_collaboration_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token is rejected (401 Unauthorized)."""
    payload = {"project_id": str(uuid.uuid4()), "talent_id": str(uuid.uuid4())}
    response = await async_client.post(
        "/api/v1/collaborations/",
        headers=expired_headers,
        json=payload,
    )
    assert response.status_code == 401


# ==============================================================================
# Validation & Reference Constraints
# ==============================================================================

@pytest.mark.asyncio
async def test_collaboration_with_nonexistent_project_rejected(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies that inviting for a non-existent project returns 404."""
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Lone PH Studio"},
    )
    t_res = await async_client.get("/api/v1/users/me", headers=talent_headers)
    t_id = t_res.json()["id"]

    payload = {
        "project_id": str(uuid.uuid4()),
        "talent_id": t_id,
        "role": "Cinematographer",
    }
    response = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json=payload,
    )
    assert response.status_code == 404
    assert "Project not found" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_collaboration_with_nonexistent_talent_rejected(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that inviting a non-existent talent returns 404."""
    ph_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Studio X"},
    )
    proj_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Project X"},
    )
    proj_id = proj_res.json()["id"]

    payload = {
        "project_id": proj_id,
        "talent_id": str(uuid.uuid4()),
        "role": "Music Composer",
    }
    response = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json=payload,
    )
    assert response.status_code == 404
    assert "Talent user not found" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_foreign_ph_cannot_invite_to_another_studios_project(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
    talent_headers: dict,
):
    """Verifies that PH2 cannot invite talent to PH1's project (404 / project ownership enforcement)."""
    _, ph1_proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    # PH2 sets up studio
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph2_headers,
        json={"company_name": "Rival PH Studio"},
    )

    payload = {
        "project_id": str(ph1_proj_id),
        "talent_id": str(talent_id),
        "role": "Sound Designer",
    }
    response = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph2_headers,
        json=payload,
    )
    assert response.status_code == 404
    assert "does not belong to your production house" in response.json().get("detail", "")


# ==============================================================================
# Collaboration Lifecycle (Invite, Accept, Reject, Status, Delete)
# ==============================================================================

@pytest.mark.asyncio
async def test_create_and_retrieve_collaboration(
    async_client: AsyncClient,
    test_db_session: AsyncSession,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies creating collaboration invitation, DB persistence, and detail retrieval."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    payload = {
        "project_id": str(proj_id),
        "talent_id": str(talent_id),
        "role": "Lead Costume Designer",
    }
    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json=payload,
    )
    assert create_res.status_code == 201
    data = create_res.json()
    assert data["project_id"] == str(proj_id)
    assert data["talent_id"] == str(talent_id)
    assert data["role"] == "Lead Costume Designer"
    assert data["status"] == "invited"
    assert "id" in data
    assert "created_at" in data
    assert "invited_at" in data
    assert data["invited_at"] == data["created_at"]
    assert data["talent"] is not None
    assert data["talent"]["id"] == str(talent_id)
    assert data["talent"]["avatar_url"] is None

    collab_id = UUID(data["id"])

    # Directly verify in PostgreSQL database
    db_collab = (await test_db_session.execute(
        select(Collaboration).where(Collaboration.id == collab_id)
    )).scalar_one_or_none()
    assert db_collab is not None
    assert db_collab.project_id == proj_id
    assert db_collab.talent_id == talent_id
    assert db_collab.role == "Lead Costume Designer"
    assert db_collab.status == "invited"
    assert db_collab.invited_at is not None

    # Retrieve by ID (Talent access)
    get_res = await async_client.get(f"/api/v1/collaborations/{collab_id}", headers=talent_headers)
    assert get_res.status_code == 200
    assert get_res.json()["id"] == str(collab_id)

    # Retrieve by ID (PH owner access)
    ph_get = await async_client.get(f"/api/v1/collaborations/{collab_id}", headers=ph_headers)
    assert ph_get.status_code == 200


@pytest.mark.asyncio
async def test_prevent_duplicate_collaboration_invitations(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies that inviting the same talent twice to the same project returns 409 Conflict."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    payload = {
        "project_id": str(proj_id),
        "talent_id": str(talent_id),
        "role": "Screenwriter",
    }
    first_res = await async_client.post("/api/v1/collaborations/", headers=ph_headers, json=payload)
    assert first_res.status_code == 201

    dup_res = await async_client.post("/api/v1/collaborations/", headers=ph_headers, json=payload)
    assert dup_res.status_code == 409
    assert "already exists" in dup_res.json().get("detail", "")


@pytest.mark.asyncio
async def test_list_collaborations_under_project_and_my(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies listing project collaborations and listing own collaborations."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Gaffer"},
    )
    collab_id = create_res.json()["id"]

    # 1. Project subroute: GET /api/v1/projects/{project_id}/collaborations
    proj_collabs = await async_client.get(f"/api/v1/projects/{proj_id}/collaborations")
    assert proj_collabs.status_code == 200
    collabs_json = proj_collabs.json()
    assert any(c["id"] == collab_id for c in collabs_json)
    target_c = next(c for c in collabs_json if c["id"] == collab_id)
    assert "invited_at" in target_c
    assert "created_at" in target_c
    assert target_c["invited_at"] == target_c["created_at"]
    assert target_c["talent"] is not None
    assert target_c["talent"]["id"] == str(talent_id)
    assert target_c["talent"]["avatar_url"] is None

    # 2. My route for PH: GET /api/v1/collaborations/my
    ph_my = await async_client.get("/api/v1/collaborations/my", headers=ph_headers)
    assert ph_my.status_code == 200
    my_json = ph_my.json()
    assert any(c["id"] == collab_id for c in my_json)
    target_my = next(c for c in my_json if c["id"] == collab_id)
    assert target_my["invited_at"] is not None
    assert target_my["talent"] is not None
    assert target_my["talent"]["id"] == str(talent_id)


@pytest.mark.asyncio
async def test_talent_accepts_collaboration(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies talent accepts invitation, status transitions to 'accepted'."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Colorist"},
    )
    collab_id = create_res.json()["id"]

    # Talent accepts
    accept_res = await async_client.patch(
        f"/api/v1/collaborations/{collab_id}/accept",
        headers=talent_headers,
    )
    assert accept_res.status_code == 200
    assert accept_res.json()["status"] == "accepted"


@pytest.mark.asyncio
async def test_talent_rejects_collaboration(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies talent rejects invitation, status transitions to 'rejected'."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Stunt Coordinator"},
    )
    collab_id = create_res.json()["id"]

    # Talent rejects
    reject_res = await async_client.patch(
        f"/api/v1/collaborations/{collab_id}/reject",
        headers=talent_headers,
    )
    assert reject_res.status_code == 200
    assert reject_res.json()["status"] == "rejected"


@pytest.mark.asyncio
async def test_ph_updates_collaboration_status(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies PH owner updates status to 'completed'."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "VFX Artist"},
    )
    collab_id = create_res.json()["id"]

    # PH updates status
    status_res = await async_client.patch(
        f"/api/v1/collaborations/{collab_id}/status",
        headers=ph_headers,
        json={"status": "completed"},
    )
    assert status_res.status_code == 200
    assert status_res.json()["status"] == "completed"


@pytest.mark.asyncio
async def test_delete_collaboration(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies deleting collaboration removes it."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Editor"},
    )
    collab_id = create_res.json()["id"]

    del_res = await async_client.delete(f"/api/v1/collaborations/{collab_id}", headers=ph_headers)
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/collaborations/{collab_id}", headers=ph_headers)
    assert get_res.status_code == 404


# ==============================================================================
# Cross-User Security Enforcement
# ==============================================================================

@pytest.mark.asyncio
async def test_another_user_cannot_accept_modify_or_view_collaboration(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies that an unrelated user (Talent 2) cannot view, accept, reject, or modify Talent 1's collaboration."""
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Foley Artist"},
    )
    collab_id = create_res.json()["id"]

    # Talent 2 attempts GET -> 403 Forbidden
    t2_get = await async_client.get(f"/api/v1/collaborations/{collab_id}", headers=talent2_headers)
    assert t2_get.status_code == 403

    # Talent 2 attempts accept -> 404 (talent_id check filters out)
    t2_accept = await async_client.patch(f"/api/v1/collaborations/{collab_id}/accept", headers=talent2_headers)
    assert t2_accept.status_code == 404

    # Talent 2 attempts reject -> 404
    t2_reject = await async_client.patch(f"/api/v1/collaborations/{collab_id}/reject", headers=talent2_headers)
    assert t2_reject.status_code == 404

    # Talent 2 attempts delete -> 403 Forbidden
    t2_del = await async_client.delete(f"/api/v1/collaborations/{collab_id}", headers=talent2_headers)
    assert t2_del.status_code == 403


@pytest.mark.asyncio
async def test_nonexistent_collaboration_returns_404(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies operations on non-existent collaboration IDs return 404."""
    random_id = uuid.uuid4()

    get_res = await async_client.get(f"/api/v1/collaborations/{random_id}", headers=talent_headers)
    assert get_res.status_code == 404

    accept_res = await async_client.patch(f"/api/v1/collaborations/{random_id}/accept", headers=talent_headers)
    assert accept_res.status_code == 404

    reject_res = await async_client.patch(f"/api/v1/collaborations/{random_id}/reject", headers=talent_headers)
    assert reject_res.status_code == 404

    del_res = await async_client.delete(f"/api/v1/collaborations/{random_id}", headers=talent_headers)
    assert del_res.status_code == 404


@pytest.mark.asyncio
async def test_collaboration_group2_nested_talent_and_timestamp_compatibility(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies Group 2 requirements for CollaborationResponse:
    1. invited_at and created_at timestamps are identical and ISO 8601.
    2. talent nested summary is populated with full details.
    3. avatar_url defaults to null without schema errors.
    4. Unauthorized foreign talent cannot view collaboration or access talent email.
    """
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Lead Sound Designer"},
    )
    assert create_res.status_code == 201
    data = create_res.json()
    collab_id = data["id"]

    # 1. Timestamps check
    assert "invited_at" in data
    assert "created_at" in data
    assert data["invited_at"] == data["created_at"]
    assert "T" in data["invited_at"]  # ISO 8601 format verification

    # 2. Nested Talent check
    assert data["talent"] is not None
    talent_data = data["talent"]
    assert talent_data["id"] == str(talent_id)
    assert "full_name" in talent_data
    assert "email" in talent_data
    assert talent_data["email"] == "talent@testcineconnect.com"
    assert "role" in talent_data
    assert "location" in talent_data
    assert "bio" in talent_data
    assert "experience_years" in talent_data
    assert "is_verified" in talent_data
    assert "skills" in talent_data
    assert talent_data["avatar_url"] is None

    # 3. Retrieve by Talent (invitee)
    t_get = await async_client.get(f"/api/v1/collaborations/{collab_id}", headers=talent_headers)
    assert t_get.status_code == 200
    assert t_get.json()["invited_at"] == data["invited_at"]
    assert t_get.json()["talent"]["id"] == str(talent_id)

    # 4. Unauthorized access prevention: foreign talent cannot view collaboration or email
    unauth_get = await async_client.get(f"/api/v1/collaborations/{collab_id}", headers=talent2_headers)
    assert unauth_get.status_code == 403


@pytest.mark.asyncio
async def test_collaboration_cannot_invite_production_house_as_talent(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
    ph2_user_id: UUID,
):
    """Verifies that a Production House cannot invite another Production House user as Talent."""
    # Ensure PH2 profile exists
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph2_headers,
        json={"company_name": "Studio Two", "contact_email": "studio2@cineconnect.com"},
    )

    # PH1 creates project
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Studio One", "contact_email": "studio1@cineconnect.com"},
    )
    proj_res = await async_client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Studio Project", "status": "development"},
    )
    proj_id = proj_res.json()["id"]

    # PH1 attempts to invite PH2 user as talent -> must be rejected with 400
    invite_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(ph2_user_id), "role": "Co-Producer"},
    )
    assert invite_res.status_code == 400
    assert "Target user is not a talent account" in invite_res.json()["detail"]


@pytest.mark.asyncio
async def test_talent_with_custom_craft_role_retrieves_my_collaborations(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that a Talent user with a custom professional craft role (e.g. Cinematographer)
    can list their collaborations via GET /api/v1/collaborations/my (account_type check).
    """
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    # Talent updates craft role from default 'talent' to 'Master Cinematographer'
    update_res = await async_client.put(
        "/api/v1/users/me",
        headers=talent_headers,
        json={
            "full_name": "Cinematographer Star",
            "role": "Master Cinematographer",
            "location": "Mumbai",
            "experience_years": 10,
        },
    )
    assert update_res.status_code == 200
    assert update_res.json()["role"] == "Master Cinematographer"

    # PH invites this talent
    invite_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Director of Photography"},
    )
    assert invite_res.status_code == 201
    collab_id = invite_res.json()["id"]

    # Talent retrieves their collaborations -> must NOT return empty list
    my_collabs = await async_client.get("/api/v1/collaborations/my", headers=talent_headers)
    assert my_collabs.status_code == 200
    items = my_collabs.json()
    assert len(items) >= 1
    assert any(c["id"] == collab_id for c in items)


@pytest.mark.asyncio
async def test_collaboration_status_alignment_and_reinvitation(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies Group 3 Collaboration Status Alignment and Re-invitation:
    1. Duplicate invitation while active returns 409 Conflict.
    2. Talent rejects -> Talent gets canonical 'rejected'.
    3. Production House views collaboration -> gets 'declined' for 'rejected'.
    4. Project team view GET /projects/{id}/collaborations -> gets 'declined'.
    5. Re-invitation after decline/rejection succeeds with updated role.
    6. Duplicate invitation while active again returns 409 Conflict.
    7. Talent accepts re-invitation.
    8. Duplicate invitation while accepted returns 409 Conflict.
    9. PH updates status accepting 'declined' alias.
    """
    _, proj_id, talent_id = await setup_project_and_talent(async_client, ph_headers, talent_headers)

    # 1. PH invites Talent
    create_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Gaffer"},
    )
    assert create_res.status_code == 201
    collab_id = create_res.json()["id"]

    # 2. Duplicate active invitation rejected
    dup_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Key Grip"},
    )
    assert dup_res.status_code == 409
    assert "already exists" in dup_res.json()["detail"]

    # 3. Talent rejects invitation
    reject_res = await async_client.patch(
        f"/api/v1/collaborations/{collab_id}/reject",
        headers=talent_headers,
    )
    assert reject_res.status_code == 200
    assert reject_res.json()["status"] == "rejected"  # Talent sees canonical 'rejected'

    # 4. Production House retrieves by ID -> sees 'declined'
    ph_get = await async_client.get(
        f"/api/v1/collaborations/{collab_id}",
        headers=ph_headers,
    )
    assert ph_get.status_code == 200
    assert ph_get.json()["status"] == "declined"  # Production House sees 'declined'

    # 5. Project team view -> sees 'declined'
    proj_team = await async_client.get(f"/api/v1/projects/{proj_id}/collaborations")
    assert proj_team.status_code == 200
    team_item = next(c for c in proj_team.json() if c["id"] == collab_id)
    assert team_item["status"] == "declined"

    # 6. Re-invitation after decline/rejection succeeds
    reinvite_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Lead Lighting Technician"},
    )
    assert reinvite_res.status_code == 201
    reinvited_data = reinvite_res.json()
    assert reinvited_data["status"] == "invited"
    assert reinvited_data["role"] == "Lead Lighting Technician"
    assert reinvited_data["id"] == collab_id  # Re-uses record cleanly

    # 7. Duplicate active invitation rejected again
    dup_active_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Gaffer"},
    )
    assert dup_active_res.status_code == 409

    # 8. Talent accepts re-invitation
    accept_res = await async_client.patch(
        f"/api/v1/collaborations/{collab_id}/accept",
        headers=talent_headers,
    )
    assert accept_res.status_code == 200
    assert accept_res.json()["status"] == "accepted"

    # 9. Duplicate accepted invitation rejected
    dup_accepted_res = await async_client.post(
        "/api/v1/collaborations/",
        headers=ph_headers,
        json={"project_id": str(proj_id), "talent_id": str(talent_id), "role": "Gaffer"},
    )
    assert dup_accepted_res.status_code == 409

    # 10. PH updates status using 'declined' alias
    status_declined = await async_client.patch(
        f"/api/v1/collaborations/{collab_id}/status",
        headers=ph_headers,
        json={"status": "declined"},
    )
    assert status_declined.status_code == 200
    assert status_declined.json()["status"] == "declined"


