import uuid
from uuid import UUID
from unittest.mock import patch
import pytest
import httpx
from httpx import AsyncClient

from app.core.config import settings
from app.services.storage import get_internal_s3_client, init_storage_buckets


# ==============================================================================
# Helper fixtures / setup
# ==============================================================================

async def setup_opportunity(
    client: AsyncClient,
    ph_headers: dict,
    status: str = "open",
) -> tuple[UUID, UUID, UUID]:
    """Helper to set up PH, project, and opportunity."""
    ph_res = await client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": "Casting Studio Inc", "location": "Mumbai"},
    )
    assert ph_res.status_code == 201
    ph_id = UUID(ph_res.json()["id"])

    proj_res = await client.post(
        "/api/v1/projects",
        headers=ph_headers,
        json={"title": "Action Thriller 2027", "genre": "Action"},
    )
    assert proj_res.status_code == 201
    proj_id = UUID(proj_res.json()["id"])

    opp_res = await client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={
            "title": "Lead Martial Artist",
            "project_id": str(proj_id),
            "role_type": "Lead",
            "status": status,
        },
    )
    assert opp_res.status_code == 201
    opp_id = UUID(opp_res.json()["id"])

    return ph_id, proj_id, opp_id


# ==============================================================================
# Role Restrictions & Authentication Matrix
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_cannot_apply_as_talent(
    async_client: AsyncClient,
    ph_headers: dict,
):
    """Verifies that a Production House account cannot submit an application (403 Forbidden)."""
    payload = {
        "opportunity_id": str(uuid.uuid4()),
        "cover_letter": "I want to act",
    }
    response = await async_client.post(
        "/api/v1/applications/",
        headers=ph_headers,
        json=payload,
    )
    assert response.status_code == 403
    assert "restricted to Talent accounts" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_unauthenticated_application_submission_rejected(async_client: AsyncClient):
    """Verifies that unauthenticated application submission is rejected (401 or 403)."""
    payload = {"opportunity_id": str(uuid.uuid4())}
    response = await async_client.post("/api/v1/applications/", json=payload)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_application_rejected(
    async_client: AsyncClient,
    invalid_headers: dict,
):
    """Verifies that invalid token is rejected (401 Unauthorized)."""
    payload = {"opportunity_id": str(uuid.uuid4())}
    response = await async_client.post(
        "/api/v1/applications/",
        headers=invalid_headers,
        json=payload,
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_application_rejected(
    async_client: AsyncClient,
    expired_headers: dict,
):
    """Verifies that expired token is rejected (401 Unauthorized)."""
    payload = {"opportunity_id": str(uuid.uuid4())}
    response = await async_client.post(
        "/api/v1/applications/",
        headers=expired_headers,
        json=payload,
    )
    assert response.status_code == 401


# ==============================================================================
# Application Submission & Validation
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_submits_application_successfully(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies successful application submission by a talent user."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    payload = {
        "opportunity_id": str(opp_id),
        "cover_letter": "I have 8 years of martial arts and screen combat experience.",
        "resume_url": "https://cdn.cineconnect.com/resumes/actor_profile.pdf",
        "reel_url": "https://vimeo.com/martial_reel",
    }
    response = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["opportunity_id"] == str(opp_id)
    assert data["talent_id"] == str(talent_user_id)
    assert data["status"] == "submitted"
    assert data["cover_letter"] == payload["cover_letter"]
    assert data["resume_url"] == payload["resume_url"]
    assert data["reel_url"] == payload["reel_url"]
    assert "created_at" in data
    assert "applied_at" in data
    assert data["applied_at"] == data["created_at"]
    assert "updated_at" in data
    assert "id" in data
    assert data["talent"] is not None
    assert data["talent"]["id"] == str(talent_user_id)
    assert data["talent"]["avatar_url"] is None


@pytest.mark.asyncio
async def test_apply_to_nonexistent_opportunity_rejected(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """Verifies submitting an application to a non-existent opportunity returns 404."""
    payload = {
        "opportunity_id": str(uuid.uuid4()),
        "cover_letter": "Application for ghost role",
    }
    response = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 404
    assert "Opportunity not found" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_apply_to_closed_opportunity_rejected(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies submitting an application to a closed opportunity returns 400 Bad Request."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="closed")

    payload = {
        "opportunity_id": str(opp_id),
        "cover_letter": "Applying anyway",
    }
    response = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json=payload,
    )
    assert response.status_code == 400
    assert "not accepting applications" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_duplicate_application_rejection(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies that talent can apply only once to the same opportunity (409 Conflict)."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    payload = {
        "opportunity_id": str(opp_id),
        "cover_letter": "First submission",
    }
    first_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json=payload,
    )
    assert first_res.status_code == 201

    # Attempt second application
    dup_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Duplicate attempt"},
    )
    assert dup_res.status_code == 409
    assert "already submitted an application" in dup_res.json().get("detail", "")


# ==============================================================================
# Retrieval & Candidate Management
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_retrieves_own_applications(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies that talent can list their submitted applications."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Talent Application"},
    )

    my_apps_res = await async_client.get("/api/v1/applications/my", headers=talent_headers)
    assert my_apps_res.status_code == 200
    apps = my_apps_res.json()
    assert len(apps) >= 1
    assert any(a["opportunity_id"] == str(opp_id) for a in apps)


@pytest.mark.asyncio
async def test_ph_retrieves_applicants_for_opportunity(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent2_headers: dict,
    talent_user_id: UUID,
    talent2_user_id: UUID,
):
    """Verifies that the opportunity's PH can list received candidate applications."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # Talent 1 applies
    await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Talent 1 application"},
    )
    # Talent 2 applies
    await async_client.post(
        "/api/v1/applications/",
        headers=talent2_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Talent 2 application"},
    )

    # 1. Via /api/v1/applications/?opportunity_id=...
    ph_apps_res = await async_client.get(
        f"/api/v1/applications/?opportunity_id={opp_id}",
        headers=ph_headers,
    )
    assert ph_apps_res.status_code == 200
    ph_apps = ph_apps_res.json()
    assert len(ph_apps) == 2

    # Verify each application includes its corresponding nested talent summary and applied_at timestamp
    for app_item in ph_apps:
        assert "applied_at" in app_item
        assert "created_at" in app_item
        assert app_item["applied_at"] == app_item["created_at"]
        assert app_item["talent"] is not None
        assert "email" in app_item["talent"]
        assert "avatar_url" in app_item["talent"]
        assert app_item["talent"]["avatar_url"] is None

    # Verify that multiple applications return the correct corresponding distinct Talent objects
    talent_ids_in_apps = {app_item["talent"]["id"] for app_item in ph_apps}
    assert len(talent_ids_in_apps) == 2
    assert str(talent_user_id) in talent_ids_in_apps
    assert str(talent2_user_id) in talent_ids_in_apps

    # 2. Via /api/v1/opportunities/{opp_id}/applications
    opp_apps_res = await async_client.get(
        f"/api/v1/opportunities/{opp_id}/applications",
        headers=ph_headers,
    )
    assert opp_apps_res.status_code == 200
    opp_apps = opp_apps_res.json()
    assert len(opp_apps) == 2
    for opp_app in opp_apps:
        assert opp_app["applied_at"] is not None
        assert opp_app["talent"] is not None
        assert opp_app["talent"]["id"] in {str(talent_user_id), str(talent2_user_id)}


# ==============================================================================
# Application Status Management & Ownership Enforcement
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_updates_application_status(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies PH updates application status: submitted -> under_review -> shortlisted -> accepted."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Candidate A"},
    )
    app_id = submit_res.json()["id"]

    # Step 1: Update status to 'under_review'
    review_res = await async_client.patch(
        f"/api/v1/applications/{app_id}/status",
        headers=ph_headers,
        json={"status": "under_review"},
    )
    assert review_res.status_code == 200
    assert review_res.json()["status"] == "under_review"

    # Step 2: Update status to 'shortlisted'
    shortlist_res = await async_client.patch(
        f"/api/v1/applications/{app_id}/status",
        headers=ph_headers,
        json={"status": "shortlisted"},
    )
    assert shortlist_res.status_code == 200
    assert shortlist_res.json()["status"] == "shortlisted"

    # Step 3: Update status to 'accepted'
    accept_res = await async_client.patch(
        f"/api/v1/applications/{app_id}/status",
        headers=ph_headers,
        json={"status": "accepted"},
    )
    assert accept_res.status_code == 200
    assert accept_res.json()["status"] == "accepted"


@pytest.mark.asyncio
async def test_foreign_ph_cannot_view_or_update_application_status(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
    talent_headers: dict,
):
    """Verifies that PH2 cannot view or modify the application submitted to PH1's opportunity."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Confidential submission"},
    )
    app_id = submit_res.json()["id"]

    # PH2 sets up studio
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph2_headers,
        json={"company_name": "Rival PH Inc"},
    )

    # PH2 attempts to view application details -> 403 Forbidden
    ph2_view = await async_client.get(
        f"/api/v1/applications/{app_id}",
        headers=ph2_headers,
    )
    assert ph2_view.status_code == 403

    # PH2 attempts to change status -> 403 Forbidden
    ph2_status = await async_client.patch(
        f"/api/v1/applications/{app_id}/status",
        headers=ph2_headers,
        json={"status": "rejected"},
    )
    assert ph2_status.status_code == 403
    assert "permission to change status" in ph2_status.json().get("detail", "")


@pytest.mark.asyncio
async def test_talent_cannot_review_or_edit_another_talents_application(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies that Talent 2 cannot view, edit, or withdraw Talent 1's application."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Talent 1 private text"},
    )
    app_id = submit_res.json()["id"]

    # Talent 2 attempts GET -> 403 Forbidden
    t2_get = await async_client.get(
        f"/api/v1/applications/{app_id}",
        headers=talent2_headers,
    )
    assert t2_get.status_code == 403

    # Talent 2 attempts PATCH -> 404 (talent filter limits to current_user.id)
    t2_patch = await async_client.patch(
        f"/api/v1/applications/{app_id}",
        headers=talent2_headers,
        json={"cover_letter": "Hacked text"},
    )
    assert t2_patch.status_code == 404

    # Talent 2 attempts DELETE -> 404
    t2_del = await async_client.delete(
        f"/api/v1/applications/{app_id}",
        headers=talent2_headers,
    )
    assert t2_del.status_code == 404


@pytest.mark.asyncio
async def test_talent_updates_and_withdraws_application(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies talent can update fields on submitted application and withdraw it."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "cover_letter": "Initial Cover Letter",
            "reel_url": "https://vimeo.com/original",
        },
    )
    app_id = submit_res.json()["id"]

    # Update fields
    patch_res = await async_client.patch(
        f"/api/v1/applications/{app_id}",
        headers=talent_headers,
        json={
            "cover_letter": "Updated Cover Letter with festival references",
            "reel_url": "https://vimeo.com/updated",
        },
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["cover_letter"] == "Updated Cover Letter with festival references"
    assert patch_res.json()["reel_url"] == "https://vimeo.com/updated"

    # Withdraw application
    del_res = await async_client.delete(
        f"/api/v1/applications/{app_id}",
        headers=talent_headers,
    )
    assert del_res.status_code == 204

    # Verification: subsequent GET returns 404
    verify_res = await async_client.get(f"/api/v1/applications/{app_id}", headers=talent_headers)
    assert verify_res.status_code == 404


@pytest.mark.asyncio
async def test_application_group2_nested_talent_and_timestamp_compatibility(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent2_headers: dict,
    talent_user_id: UUID,
):
    """Verifies Group 2 requirements for ApplicationResponse:
    1. applied_at and created_at timestamps are identical and ISO 8601.
    2. talent nested summary is populated with full details.
    3. avatar_url defaults to null without schema errors.
    4. Unauthorized foreign talent cannot view application or access talent email.
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Lead Actor applicant"},
    )
    assert submit_res.status_code == 201
    data = submit_res.json()
    app_id = data["id"]

    # 1. Timestamps check
    assert "applied_at" in data
    assert "created_at" in data
    assert data["applied_at"] == data["created_at"]
    assert "T" in data["applied_at"]  # ISO 8601 format verification

    # 2. Nested Talent check
    assert data["talent"] is not None
    talent_data = data["talent"]
    assert talent_data["id"] == str(talent_user_id)
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

    # 3. Retrieve by Production House owner
    ph_get = await async_client.get(f"/api/v1/applications/{app_id}", headers=ph_headers)
    assert ph_get.status_code == 200
    ph_data = ph_get.json()
    assert ph_data["status"] == "received"
    assert ph_data["talent"]["email"] == "talent@testcineconnect.com"
    assert ph_data["applied_at"] == data["applied_at"]

    # 4. Unauthorized access prevention: foreign talent cannot view application or email
    unauth_get = await async_client.get(f"/api/v1/applications/{app_id}", headers=talent2_headers)
    assert unauth_get.status_code == 403


@pytest.mark.asyncio
async def test_application_group3_status_alignment(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies Group 3 Application Status Alignment:
    1. Talent submits -> gets canonical 'submitted'.
    2. Talent lists own applications -> gets canonical 'submitted'.
    3. Production House lists candidate applications -> gets 'received' for 'submitted'.
    4. Production House filters by ?status=received -> matches applications stored as 'submitted'.
    5. Production House attempts to reset status to 'received' or 'submitted' -> rejected with 400.
    6. Production House updates status to 'under_review' and 'shortlisted' -> works cleanly.
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # 1. Talent submits application
    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "Actor application"},
    )
    assert submit_res.status_code == 201
    talent_submit_data = submit_res.json()
    assert talent_submit_data["status"] == "submitted"
    app_id = talent_submit_data["id"]

    # 2. Talent views own application list
    talent_my = await async_client.get("/api/v1/applications/my", headers=talent_headers)
    assert talent_my.status_code == 200
    my_app = next(a for a in talent_my.json() if a["id"] == app_id)
    assert my_app["status"] == "submitted"

    # 3. Production House views candidate applications list
    ph_list = await async_client.get(
        f"/api/v1/applications/?opportunity_id={opp_id}",
        headers=ph_headers,
    )
    assert ph_list.status_code == 200
    ph_app = next(a for a in ph_list.json() if a["id"] == app_id)
    assert ph_app["status"] == "received"

    # 4. Production House filters with ?status=received
    ph_filter_received = await async_client.get(
        f"/api/v1/applications/?opportunity_id={opp_id}&status=received",
        headers=ph_headers,
    )
    assert ph_filter_received.status_code == 200
    assert len(ph_filter_received.json()) == 1
    assert ph_filter_received.json()[0]["id"] == app_id
    assert ph_filter_received.json()[0]["status"] == "received"

    # 5. Production House cannot reset status to 'received' or 'submitted'
    reset_received = await async_client.patch(
        f"/api/v1/applications/{app_id}/status",
        headers=ph_headers,
        json={"status": "received"},
    )
    assert reset_received.status_code == 400
    assert "Cannot reset application status" in reset_received.json()["detail"]

    reset_submitted = await async_client.patch(
        f"/api/v1/applications/{app_id}/status",
        headers=ph_headers,
        json={"status": "submitted"},
    )
    assert reset_submitted.status_code == 400
    assert "Cannot reset application status" in reset_submitted.json()["detail"]

    # 6. Production House updates status to 'under_review'
    review_res = await async_client.patch(
        f"/api/v1/applications/{app_id}/status",
        headers=ph_headers,
        json={"status": "under_review"},
    )
    assert review_res.status_code == 200
    assert review_res.json()["status"] == "under_review"


# ==============================================================================
# Group 3B: Application Resume & Audition Reel Privacy Integration Tests
# ==============================================================================

def put_test_minio_object(bucket: str, file_key: str, content: bytes = b"%PDF-1.4\nTest PDF Content", content_type: str = "application/pdf"):
    """Helper to populate an object in MinIO for tests verifying head_object existence."""
    s3 = get_internal_s3_client()
    s3.put_object(Bucket=bucket, Key=file_key, Body=content, ContentType=content_type)


@pytest.mark.asyncio
async def test_application_private_resume_and_reel_upload_and_submission(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies Talent uploads resume and audition reel using purpose='private'
    and submits application; response contains temporary presigned download URLs.
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # 1. Request presigned upload URL for private resume
    resume_upload_res = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "actor_private_cv.pdf", "content_type": "application/pdf", "purpose": "private"},
    )
    assert resume_upload_res.status_code == 200
    resume_data = resume_upload_res.json()
    assert resume_data["bucket"] == settings.MINIO_PRIVATE_BUCKET
    assert resume_data["purpose"] == "private"
    resume_file_key = resume_data["file_key"]

    # 2. Request presigned upload URL for private audition reel
    reel_upload_res = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "audition_screen_test.mp4", "content_type": "video/mp4", "purpose": "private"},
    )
    assert reel_upload_res.status_code == 200
    reel_data = reel_upload_res.json()
    assert reel_data["bucket"] == settings.MINIO_PRIVATE_BUCKET
    reel_file_key = reel_data["file_key"]

    # Populate objects in MinIO so head_object existence verification succeeds
    put_test_minio_object(settings.MINIO_PRIVATE_BUCKET, resume_file_key, b"%PDF-1.4\nActor Resume", "application/pdf")
    put_test_minio_object(settings.MINIO_PRIVATE_BUCKET, reel_file_key, b"\x00\x00\x00 mp4\nActor Reel", "video/mp4")

    # 3. Submit application referencing these private files
    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "cover_letter": "Enclosed is my confidential CV and reel.",
            "resume_url": resume_file_key,
            "reel_url": reel_file_key,
        },
    )
    assert submit_res.status_code == 201
    app_data = submit_res.json()
    app_id = app_data["id"]

    # Response should contain presigned download URLs for the private assets
    assert "X-Amz-Signature=" in app_data["resume_url"]
    assert "X-Amz-Signature=" in app_data["reel_url"]
    assert settings.MINIO_PRIVATE_BUCKET in app_data["resume_url"]
    assert settings.MINIO_PRIVATE_BUCKET in app_data["reel_url"]

    # 4. Talent retrieves application details via GET /{application_id}
    detail_res = await async_client.get(f"/api/v1/applications/{app_id}", headers=talent_headers)
    assert detail_res.status_code == 200
    detail_data = detail_res.json()
    assert "X-Amz-Signature=" in detail_data["resume_url"]
    assert "X-Amz-Signature=" in detail_data["reel_url"]

    # Clean up test objects
    s3 = get_internal_s3_client()
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=resume_file_key)
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=reel_file_key)


@pytest.mark.asyncio
async def test_application_cannot_attach_another_talents_private_file(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent2_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that Talent 2 cannot attach Talent 1's private media key to their application (403 Forbidden)."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # Talent 1 generates a private upload key
    t1_upload = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "t1_cv.pdf", "content_type": "application/pdf", "purpose": "private"},
    )
    t1_key = t1_upload.json()["file_key"]
    assert str(talent_user_id) in t1_key

    # Talent 2 attempts to submit application using Talent 1's private key -> rejected with 403
    t2_submit = await async_client.post(
        "/api/v1/applications/",
        headers=talent2_headers,
        json={
            "opportunity_id": str(opp_id),
            "cover_letter": "Fraudulent application with stolen key",
            "resume_url": t1_key,
        },
    )
    assert t2_submit.status_code == 403
    assert "belonging to another user" in t2_submit.json()["detail"]


@pytest.mark.asyncio
async def test_application_cannot_attach_public_bucket_file_as_resume(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies that submitting a public bucket URL for a resume is rejected (400 Bad Request)."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # Talent requests upload URL with default/explicit public purpose
    pub_upload = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "public_doc.pdf", "content_type": "application/pdf", "purpose": "public"},
    )
    pub_url = pub_upload.json()["public_url"]
    assert settings.MINIO_PUBLIC_BUCKET in pub_url

    # Submitting application with public URL for resume -> rejected with 400
    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "resume_url": pub_url,
        },
    )
    assert submit_res.status_code == 400
    assert "must be uploaded with purpose='private'" in submit_res.json()["detail"]


@pytest.mark.asyncio
async def test_application_download_url_endpoints_authorized_access(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that both the application-owning Talent and the opportunity-owning Production House
    can access the dedicated resume and reel presigned download endpoints.
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # Talent generates private keys and submits application
    resume_up = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "resume.pdf", "content_type": "application/pdf", "purpose": "private"},
    )
    reel_up = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "reel.mp4", "content_type": "video/mp4", "purpose": "private"},
    )
    resume_key = resume_up.json()["file_key"]
    reel_key = reel_up.json()["file_key"]

    put_test_minio_object(settings.MINIO_PRIVATE_BUCKET, resume_key, b"%PDF-1.4\nResume", "application/pdf")
    put_test_minio_object(settings.MINIO_PRIVATE_BUCKET, reel_key, b"\x00\x00\x00 mp4\nReel", "video/mp4")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "resume_url": resume_key,
            "reel_url": reel_key,
        },
    )
    app_id = submit_res.json()["id"]

    # 1. Talent accesses resume download URL
    t_resume_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/resume-download-url",
        headers=talent_headers,
    )
    assert t_resume_dl.status_code == 200
    t_resume_data = t_resume_dl.json()
    assert t_resume_data["file_type"] == "resume"
    assert "X-Amz-Signature=" in t_resume_data["download_url"]
    assert settings.MINIO_PRIVATE_BUCKET in t_resume_data["download_url"]

    # 2. Talent accesses reel download URL
    t_reel_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/reel-download-url",
        headers=talent_headers,
    )
    assert t_reel_dl.status_code == 200
    t_reel_data = t_reel_dl.json()
    assert t_reel_data["file_type"] == "reel"
    assert "X-Amz-Signature=" in t_reel_data["download_url"]

    # 3. Opportunity's Production House accesses resume download URL
    ph_resume_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/resume-download-url",
        headers=ph_headers,
    )
    assert ph_resume_dl.status_code == 200
    assert "X-Amz-Signature=" in ph_resume_dl.json()["download_url"]

    # 4. Opportunity's Production House accesses reel download URL
    ph_reel_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/reel-download-url",
        headers=ph_headers,
    )
    assert ph_reel_dl.status_code == 200
    assert "X-Amz-Signature=" in ph_reel_dl.json()["download_url"]

    # Cleanup
    s3 = get_internal_s3_client()
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=resume_key)
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=reel_key)


@pytest.mark.asyncio
async def test_application_download_url_endpoints_unauthorized_access(
    async_client: AsyncClient,
    ph_headers: dict,
    ph2_headers: dict,
    talent_headers: dict,
    talent2_headers: dict,
):
    """Verifies that unrelated Talent, unrelated Production House, and unauthenticated requests
    are properly rejected (401/403) for BOTH resume and reel download endpoints.
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    resume_up = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "confidential_cv.pdf", "content_type": "application/pdf", "purpose": "private"},
    )
    reel_up = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "confidential_reel.mp4", "content_type": "video/mp4", "purpose": "private"},
    )
    resume_key = resume_up.json()["file_key"]
    reel_key = reel_up.json()["file_key"]

    put_test_minio_object(settings.MINIO_PRIVATE_BUCKET, resume_key, b"%PDF-1.4\nResume", "application/pdf")
    put_test_minio_object(settings.MINIO_PRIVATE_BUCKET, reel_key, b"\x00\x00\x00 mp4\nReel", "video/mp4")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "resume_url": resume_key,
            "reel_url": reel_key,
        },
    )
    app_id = submit_res.json()["id"]

    # Create PH2 profile so it's a valid but unrelated PH
    await async_client.post(
        "/api/v1/production-houses",
        headers=ph2_headers,
        json={"company_name": "Unrelated Studio Ltd"},
    )

    # 1. Unrelated Talent (Talent 2) -> 403 Forbidden for both resume and reel
    t2_resume_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/resume-download-url",
        headers=talent2_headers,
    )
    assert t2_resume_dl.status_code == 403
    assert "permission to access private files" in t2_resume_dl.json()["detail"]

    t2_reel_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/reel-download-url",
        headers=talent2_headers,
    )
    assert t2_reel_dl.status_code == 403
    assert "permission to access private files" in t2_reel_dl.json()["detail"]

    # 2. Unrelated Production House (PH 2) -> 403 Forbidden for both resume and reel
    ph2_resume_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/resume-download-url",
        headers=ph2_headers,
    )
    assert ph2_resume_dl.status_code == 403
    assert "permission to access private files" in ph2_resume_dl.json()["detail"]

    ph2_reel_dl = await async_client.get(
        f"/api/v1/applications/{app_id}/reel-download-url",
        headers=ph2_headers,
    )
    assert ph2_reel_dl.status_code == 403
    assert "permission to access private files" in ph2_reel_dl.json()["detail"]

    # 3. Unauthenticated request -> 401 Unauthorized for both resume and reel
    anon_resume_dl = await async_client.get(f"/api/v1/applications/{app_id}/resume-download-url")
    assert anon_resume_dl.status_code in (401, 403)

    anon_reel_dl = await async_client.get(f"/api/v1/applications/{app_id}/reel-download-url")
    assert anon_reel_dl.status_code in (401, 403)

    # 4. Nonexistent application ID -> 404 Not Found for both
    random_id = uuid.uuid4()
    not_found_resume = await async_client.get(
        f"/api/v1/applications/{random_id}/resume-download-url",
        headers=ph_headers,
    )
    assert not_found_resume.status_code == 404

    not_found_reel = await async_client.get(
        f"/api/v1/applications/{random_id}/reel-download-url",
        headers=ph_headers,
    )
    assert not_found_reel.status_code == 404

    # Cleanup
    s3 = get_internal_s3_client()
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=resume_key)
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=reel_key)


@pytest.mark.asyncio
async def test_application_download_url_endpoint_missing_file_returns_404(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies 404 Not Found when requesting download URL for an application without that file type."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "cover_letter": "No files attached"},
    )
    app_id = submit_res.json()["id"]

    # Request resume download URL when none is attached
    no_resume = await async_client.get(
        f"/api/v1/applications/{app_id}/resume-download-url",
        headers=talent_headers,
    )
    assert no_resume.status_code == 404
    assert "does not have a resume attached" in no_resume.json()["detail"]

    # Request reel download URL when none is attached
    no_reel = await async_client.get(
        f"/api/v1/applications/{app_id}/reel-download-url",
        headers=talent_headers,
    )
    assert no_reel.status_code == 404
    assert "does not have an audition reel attached" in no_reel.json()["detail"]


@pytest.mark.asyncio
async def test_live_minio_application_private_resume_e2e(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Live MinIO end-to-end integration test:
    1. Talent generates private upload URL and uploads actual PDF binary to cineconnect-private.
    2. Talent submits application with the private file key.
    3. Production House requests resume download URL.
    4. Production House downloads object from MinIO with presigned GET URL (succeeds 200).
    5. Direct anonymous GET to canonical URL fails with 403 (verifies private isolation).
    """
    init_storage_buckets()
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # 1. Talent requests private upload URL
    upload_res = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "talent_live_audition_cv.pdf", "content_type": "application/pdf", "purpose": "private"},
    )
    assert upload_res.status_code == 200
    upload_data = upload_res.json()
    upload_url = upload_data["upload_url"]
    file_key = upload_data["file_key"]
    canonical_public_url = upload_data["public_url"]

    # Upload binary content via presigned PUT to MinIO
    pdf_bytes = b"%PDF-1.4\n%CineConnect Confidential Actor Resume Content\n%%EOF"
    async with httpx.AsyncClient() as http_client:
        put_resp = await http_client.put(
            upload_url,
            content=pdf_bytes,
            headers={"Content-Type": "application/pdf"},
        )
        assert put_resp.status_code == 200, f"MinIO PUT failed: {put_resp.status_code} {put_resp.text}"

    # 2. Talent submits application with private key
    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "cover_letter": "Live E2E test application",
            "resume_url": file_key,
        },
    )
    assert submit_res.status_code == 201
    app_id = submit_res.json()["id"]

    # 3. Production House obtains presigned download URL
    dl_res = await async_client.get(
        f"/api/v1/applications/{app_id}/resume-download-url",
        headers=ph_headers,
    )
    assert dl_res.status_code == 200
    download_url = dl_res.json()["download_url"]

    # 4. Download content using presigned URL without any auth headers -> 200 OK
    async with httpx.AsyncClient() as http_client:
        get_resp = await http_client.get(download_url)
        assert get_resp.status_code == 200, f"Download failed: {get_resp.status_code}"
        assert get_resp.content == pdf_bytes, "Downloaded content does not match uploaded PDF bytes"

    # 5. Direct unauthenticated GET to canonical URL -> 403 Forbidden (proves private bucket remains private)
    async with httpx.AsyncClient() as http_client:
        anon_resp = await http_client.get(canonical_public_url)
        assert anon_resp.status_code in (403, 404), (
            f"Expected anonymous GET to fail with 403/404, got {anon_resp.status_code}"
        )

    # 6. Cleanup S3 object
    s3 = get_internal_s3_client()
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=file_key)


# ==============================================================================
# Group 3B Final Hardening Tests: LOW-01 (Object Existence) & MED-01 Verification
# ==============================================================================

@pytest.mark.asyncio
async def test_application_submission_missing_object_rejected_400(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies that submitting an application with a generated key whose object
    was never uploaded to MinIO is rejected with HTTP 400 Bad Request.
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    # 1. Talent requests upload URL but DOES NOT upload file
    upload_res = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "never_uploaded.pdf", "content_type": "application/pdf", "purpose": "private"},
    )
    assert upload_res.status_code == 200
    file_key = upload_res.json()["file_key"]

    # 2. Talent attempts to submit application with un-uploaded key -> 400 Bad Request
    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "cover_letter": "Application with un-uploaded document",
            "resume_url": file_key,
        },
    )
    assert submit_res.status_code == 400
    assert "does not exist in storage or has not finished uploading" in submit_res.json()["detail"]


@pytest.mark.asyncio
async def test_application_submission_fabricated_key_rejected_400(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that fabricating a syntactically valid key with own user ID
    is rejected with HTTP 400 Bad Request if the object does not exist in MinIO.
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    fake_uuid = uuid.uuid4()
    fabricated_key = f"media/{talent_user_id}/{fake_uuid}/fabricated_cv.pdf"

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "cover_letter": "Application with fabricated key",
            "resume_url": fabricated_key,
        },
    )
    assert submit_res.status_code == 400
    assert "does not exist in storage or has not finished uploading" in submit_res.json()["detail"]


@pytest.mark.asyncio
async def test_application_submission_storage_service_failure_returns_503(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that an unexpected storage service outage during existence verification
    returns HTTP 503 Service Unavailable without exposing internal credentials or tracebacks.
    """
    from fastapi import HTTPException
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    test_key = f"media/{talent_user_id}/{uuid.uuid4()}/resume.pdf"

    with patch(
        "app.services.storage.check_storage_object_exists",
        side_effect=HTTPException(
            status_code=503,
            detail="Media storage service is temporarily unavailable. Please try again later.",
        ),
    ):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={
                "opportunity_id": str(opp_id),
                "cover_letter": "Service outage test",
                "resume_url": test_key,
            },
        )
        assert submit_res.status_code == 503
        data = submit_res.json()
        assert "temporarily unavailable" in data["detail"]
        # Ensure no AWS/MinIO credentials or internal endpoints leaked
        assert "minioadmin" not in submit_res.text
        assert "SecretAccessKey" not in submit_res.text


@pytest.mark.asyncio
async def test_application_submission_external_url_with_media_in_path_accepted(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """Verifies that external URLs containing '/media/' in their path or query
    (e.g. Vimeo, YouTube, portfolio CDNs) are accepted and NOT misclassified as MinIO objects (MED-01 fix).
    """
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    external_reel_url = "https://vimeo.com/media/director_cut_2026.mp4"

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={
            "opportunity_id": str(opp_id),
            "cover_letter": "External portfolio application",
            "reel_url": external_reel_url,
        },
    )
    assert submit_res.status_code == 201
    app_data = submit_res.json()
    assert app_data["reel_url"] == external_reel_url


@pytest.mark.asyncio
async def test_application_duplicate_object_keys_avoids_duplicate_head_requests(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that attaching the same storage key to both resume and reel
    only checks MinIO head_object once (deduplication of storage checks).
    """
    import app.services.storage as storage_mod
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")

    upload_res = await async_client.post(
        "/api/v1/media/upload-url",
        headers=talent_headers,
        json={"file_name": "combined_portfolio.pdf", "content_type": "application/pdf", "purpose": "private"},
    )
    assert upload_res.status_code == 200
    file_key = upload_res.json()["file_key"]
    put_test_minio_object(settings.MINIO_PRIVATE_BUCKET, file_key, b"%PDF-1.4\nCombined", "application/pdf")

    original_check = storage_mod.check_storage_object_exists
    call_count = 0

    def counting_check(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        return original_check(*args, **kwargs)

    with patch.object(storage_mod, "check_storage_object_exists", side_effect=counting_check):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={
                "opportunity_id": str(opp_id),
                "cover_letter": "Combined portfolio",
                "resume_url": file_key,
                "reel_url": file_key,
            },
        )
        assert submit_res.status_code == 201
        assert call_count == 1, f"Expected exactly 1 head_object check, got {call_count}"

    # Cleanup
    s3 = get_internal_s3_client()
    s3.delete_object(Bucket=settings.MINIO_PRIVATE_BUCKET, Key=file_key)




