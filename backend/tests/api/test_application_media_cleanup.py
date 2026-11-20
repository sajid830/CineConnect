"""Tests for CineConnect MinIO Group 3C.2: Reference-Safe Application Media Cleanup.

Covers all 17 required scenarios:
1. Withdraw application with an unshared private resume: object deleted after DB commit.
2. Withdraw application with a shared resume: object remains.
3. Withdraw application with a shared audition reel: object remains.
4. Same object referenced as one application's resume and another application's reel: object remains.
5. External Vimeo URL: no MinIO deletion attempt.
6. External YouTube URL: no MinIO deletion attempt.
7. Talent cannot withdraw another Talent's application.
8. Production House opportunity deletion does not delete private applicant media.
9. Production House project deletion does not delete private applicant media.
10. MinIO deletion failure does not undo successful application withdrawal.
11. Database commit failure does not trigger MinIO deletion.
12. Replacing an unshared resume cleans up the old file after commit.
13. Replacing a shared resume retains the old file.
14. Clearing a media field cleans up only if unreferenced and supported by existing API contract.
15. Failed reference query never triggers deletion.
16. Relative object keys and full MinIO URLs resolving to the same key are treated as the same reference.
17. Duplicate URLs in one cleanup request are processed only once.
"""
import uuid
from uuid import UUID
from unittest.mock import patch, MagicMock
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.services.storage import (
    count_application_media_references,
    cleanup_unreferenced_application_media,
    StorageConnectionError,
)
from tests.api.test_applications import setup_opportunity


# ==============================================================================
# Helpers
# ==============================================================================

async def add_second_opportunity(async_client: AsyncClient, ph_headers: dict, proj_id: UUID) -> UUID:
    """Creates a second opportunity under the same project."""
    opp_res = await async_client.post(
        "/api/v1/opportunities/",
        headers=ph_headers,
        json={
            "title": f"Secondary Role {uuid.uuid4().hex[:6]}",
            "project_id": str(proj_id),
            "role_type": "Supporting",
            "status": "open",
        },
    )
    assert opp_res.status_code == 201
    return UUID(opp_res.json()["id"])


# ==============================================================================
# 1. Withdraw Application with Unshared Private Resume
# ==============================================================================

@pytest.mark.asyncio
async def test_withdraw_application_unshared_resume_deleted(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """1. Withdraw application with an unshared private resume: object is deleted after DB commit."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/unshared_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={
                "opportunity_id": str(opp_id),
                "cover_letter": "First application",
                "resume_url": resume_key,
            },
        )
        assert submit_res.status_code == 201
        app_id = submit_res.json()["id"]

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        del_res = await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent_headers)
        assert del_res.status_code == 204

        # Verify object was deleted from private bucket
        mock_delete.assert_called_once_with(
            bucket_name=settings.MINIO_PRIVATE_BUCKET,
            file_key=resume_key,
            s3_client=None,
        )

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/applications/{app_id}", headers=talent_headers)
    assert get_res.status_code == 404


# ==============================================================================
# 2. Withdraw Application with Shared Resume: Object Remains
# ==============================================================================

@pytest.mark.asyncio
async def test_withdraw_application_shared_resume_retained(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """2. Withdraw application with a shared resume: object remains in MinIO."""
    _, proj_id, opp1_id = await setup_opportunity(async_client, ph_headers, status="open")
    opp2_id = await add_second_opportunity(async_client, ph_headers, proj_id)

    shared_resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/master_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        # Application 1
        res1 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp1_id), "resume_url": shared_resume_key},
        )
        assert res1.status_code == 201
        app1_id = res1.json()["id"]

        # Application 2
        res2 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp2_id), "resume_url": shared_resume_key},
        )
        assert res2.status_code == 201
        app2_id = res2.json()["id"]

    # Talent withdraws Application 1
    with patch("app.services.storage.delete_storage_object") as mock_delete:
        del_res = await async_client.delete(f"/api/v1/applications/{app1_id}", headers=talent_headers)
        assert del_res.status_code == 204

        # delete_storage_object must NOT be called because Application 2 still references the resume
        mock_delete.assert_not_called()

    # Application 2 still exists and points to the shared resume
    app2_get = await async_client.get(f"/api/v1/applications/{app2_id}", headers=talent_headers)
    assert app2_get.status_code == 200


# ==============================================================================
# 3. Withdraw Application with Shared Audition Reel: Object Remains
# ==============================================================================

@pytest.mark.asyncio
async def test_withdraw_application_shared_reel_retained(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """3. Withdraw application with a shared audition reel: object remains in MinIO."""
    _, proj_id, opp1_id = await setup_opportunity(async_client, ph_headers, status="open")
    opp2_id = await add_second_opportunity(async_client, ph_headers, proj_id)

    shared_reel_key = f"media/{talent_user_id}/{uuid.uuid4()}/audition_reel.mp4"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res1 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp1_id), "reel_url": shared_reel_key},
        )
        assert res1.status_code == 201
        app1_id = res1.json()["id"]

        res2 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp2_id), "reel_url": shared_reel_key},
        )
        assert res2.status_code == 201

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        del_res = await async_client.delete(f"/api/v1/applications/{app1_id}", headers=talent_headers)
        assert del_res.status_code == 204
        mock_delete.assert_not_called()


# ==============================================================================
# 4. Cross-Field Shared Media: Resume in App 1 and Reel in App 2
# ==============================================================================

@pytest.mark.asyncio
async def test_cross_field_shared_media_retained(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """4. Same object referenced as one application's resume and another application's reel: object remains."""
    _, proj_id, opp1_id = await setup_opportunity(async_client, ph_headers, status="open")
    opp2_id = await add_second_opportunity(async_client, ph_headers, proj_id)

    multi_use_key = f"media/{talent_user_id}/{uuid.uuid4()}/portfolio_doc.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res1 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp1_id), "resume_url": multi_use_key},
        )
        assert res1.status_code == 201
        app1_id = res1.json()["id"]

        res2 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp2_id), "reel_url": multi_use_key},
        )
        assert res2.status_code == 201

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        del_res = await async_client.delete(f"/api/v1/applications/{app1_id}", headers=talent_headers)
        assert del_res.status_code == 204
        mock_delete.assert_not_called()


# ==============================================================================
# 5. External Vimeo URL: No MinIO Deletion Attempt
# ==============================================================================

@pytest.mark.asyncio
async def test_withdraw_application_external_vimeo_no_deletion(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """5. External Vimeo URL: no MinIO deletion attempt."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    vimeo_url = "https://vimeo.com/987654321"

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "reel_url": vimeo_url},
    )
    assert submit_res.status_code == 201
    app_id = submit_res.json()["id"]

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        del_res = await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent_headers)
        assert del_res.status_code == 204
        mock_delete.assert_not_called()


# ==============================================================================
# 6. External YouTube URL: No MinIO Deletion Attempt
# ==============================================================================

@pytest.mark.asyncio
async def test_withdraw_application_external_youtube_no_deletion(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """6. External YouTube URL: no MinIO deletion attempt."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    yt_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

    submit_res = await async_client.post(
        "/api/v1/applications/",
        headers=talent_headers,
        json={"opportunity_id": str(opp_id), "reel_url": yt_url},
    )
    assert submit_res.status_code == 201
    app_id = submit_res.json()["id"]

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        del_res = await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent_headers)
        assert del_res.status_code == 204
        mock_delete.assert_not_called()


# ==============================================================================
# 7. Talent Cannot Withdraw Another Talent's Application
# ==============================================================================

@pytest.mark.asyncio
async def test_talent_cannot_withdraw_another_talents_application(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
    talent2_headers: dict,
):
    """7. Talent cannot withdraw another Talent's application."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/t1_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "resume_url": resume_key},
        )
        assert submit_res.status_code == 201
        app_id = submit_res.json()["id"]

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        # Talent 2 attempts to withdraw Talent 1's application
        del_res = await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent2_headers)
        assert del_res.status_code == 404
        mock_delete.assert_not_called()

    # Application still exists
    get_res = await async_client.get(f"/api/v1/applications/{app_id}", headers=talent_headers)
    assert get_res.status_code == 200


# ==============================================================================
# 8. PH Opportunity Deletion Does Not Delete Applicant Media
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_opportunity_deletion_does_not_delete_applicant_media(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """8. Production House opportunity deletion does not delete private applicant media."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/applicant_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "resume_url": resume_key},
        )
        assert submit_res.status_code == 201

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        # Production House deletes the opportunity
        opp_del_res = await async_client.delete(f"/api/v1/opportunities/{opp_id}", headers=ph_headers)
        assert opp_del_res.status_code == 204

        # MinIO deletion must NEVER be called by an opportunity deletion
        mock_delete.assert_not_called()


# ==============================================================================
# 9. PH Project Deletion Does Not Delete Applicant Media
# ==============================================================================

@pytest.mark.asyncio
async def test_ph_project_deletion_does_not_delete_applicant_media(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """9. Production House project deletion does not delete private applicant media."""
    _, proj_id, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    reel_key = f"media/{talent_user_id}/{uuid.uuid4()}/applicant_reel.mp4"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "reel_url": reel_key},
        )
        assert submit_res.status_code == 201

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        # Production House deletes the parent project
        proj_del_res = await async_client.delete(f"/api/v1/projects/{proj_id}", headers=ph_headers)
        assert proj_del_res.status_code == 204

        # MinIO deletion must NEVER be called by a project deletion
        mock_delete.assert_not_called()


# ==============================================================================
# 10. MinIO Deletion Failure Does Not Undo Successful Withdrawal
# ==============================================================================

@pytest.mark.asyncio
async def test_minio_deletion_failure_does_not_undo_withdrawal(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """10. MinIO deletion failure does not undo successful application withdrawal."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/outage_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "resume_url": resume_key},
        )
        assert submit_res.status_code == 201
        app_id = submit_res.json()["id"]

    # Simulate MinIO storage outage during deletion
    with patch(
        "app.services.storage.delete_storage_object",
        side_effect=StorageConnectionError("MinIO connection timeout"),
    ):
        del_res = await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent_headers)
        # Withdrawal response must still succeed (HTTP 204)
        assert del_res.status_code == 204

    # Application record was successfully deleted from PostgreSQL
    get_res = await async_client.get(f"/api/v1/applications/{app_id}", headers=talent_headers)
    assert get_res.status_code == 404


# ==============================================================================
# 11. Database Commit Failure Does Not Trigger MinIO Deletion
# ==============================================================================

@pytest.mark.asyncio
async def test_db_commit_failure_does_not_trigger_minio_deletion(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """11. Database commit failure does not trigger MinIO deletion."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/rollback_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "resume_url": resume_key},
        )
        assert submit_res.status_code == 201
        app_id = submit_res.json()["id"]

    with patch("sqlalchemy.ext.asyncio.AsyncSession.commit", side_effect=RuntimeError("DB Commit failed")):
        with patch("app.services.storage.delete_storage_object") as mock_delete:
            with pytest.raises(RuntimeError, match="DB Commit failed"):
                await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent_headers)

            # MinIO deletion must NEVER be called if DB commit fails
            mock_delete.assert_not_called()


# ==============================================================================
# 12. Replacing Unshared Resume Cleans Up Old File
# ==============================================================================

@pytest.mark.asyncio
async def test_replace_unshared_resume_cleans_up_old_file(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """12. Replacing an unshared resume cleans up the old file after commit."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    old_resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/v1_resume.pdf"
    new_resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/v2_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "resume_url": old_resume_key},
        )
        assert submit_res.status_code == 201
        app_id = submit_res.json()["id"]

        with patch("app.services.storage.delete_storage_object") as mock_delete:
            patch_res = await async_client.patch(
                f"/api/v1/applications/{app_id}",
                headers=talent_headers,
                json={"resume_url": new_resume_key},
            )
            assert patch_res.status_code == 200

            # Old resume deleted, new resume retained
            mock_delete.assert_called_once_with(
                bucket_name=settings.MINIO_PRIVATE_BUCKET,
                file_key=old_resume_key,
                s3_client=None,
            )


# ==============================================================================
# 13. Replacing Shared Resume Retains Old File
# ==============================================================================

@pytest.mark.asyncio
async def test_replace_shared_resume_retains_old_file(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """13. Replacing a shared resume retains the old file."""
    _, proj_id, opp1_id = await setup_opportunity(async_client, ph_headers, status="open")
    opp2_id = await add_second_opportunity(async_client, ph_headers, proj_id)

    shared_resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/common_resume.pdf"
    new_resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/custom_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res1 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp1_id), "resume_url": shared_resume_key},
        )
        app1_id = res1.json()["id"]

        res2 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp2_id), "resume_url": shared_resume_key},
        )
        assert res2.status_code == 201

        with patch("app.services.storage.delete_storage_object") as mock_delete:
            # Replace resume on Application 1 only
            patch_res = await async_client.patch(
                f"/api/v1/applications/{app1_id}",
                headers=talent_headers,
                json={"resume_url": new_resume_key},
            )
            assert patch_res.status_code == 200

            # shared_resume_key must NOT be deleted because Application 2 still references it
            mock_delete.assert_not_called()


# ==============================================================================
# 14. Clearing Media Field Cleans Up Only If Unreferenced
# ==============================================================================

@pytest.mark.asyncio
async def test_clearing_media_cleans_up_if_unreferenced(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """14. Clearing a media field with null cleans up only if unreferenced."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    unshared_reel_key = f"media/{talent_user_id}/{uuid.uuid4()}/cleared_reel.mp4"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "reel_url": unshared_reel_key},
        )
        assert submit_res.status_code == 201
        app_id = submit_res.json()["id"]

        with patch("app.services.storage.delete_storage_object") as mock_delete:
            patch_res = await async_client.patch(
                f"/api/v1/applications/{app_id}",
                headers=talent_headers,
                json={"reel_url": None},
            )
            assert patch_res.status_code == 200

            # Unshared reel was cleared and must be cleaned up
            mock_delete.assert_called_once_with(
                bucket_name=settings.MINIO_PRIVATE_BUCKET,
                file_key=unshared_reel_key,
                s3_client=None,
            )


# ==============================================================================
# 15. Failed Reference Query Never Triggers Deletion
# ==============================================================================

@pytest.mark.asyncio
async def test_failed_reference_query_never_triggers_deletion(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """15. Failed reference query never triggers deletion."""
    _, _, opp_id = await setup_opportunity(async_client, ph_headers, status="open")
    resume_key = f"media/{talent_user_id}/{uuid.uuid4()}/fail_safe_resume.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        submit_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "resume_url": resume_key},
        )
        assert submit_res.status_code == 201
        app_id = submit_res.json()["id"]

    # Simulate database error during reference counting
    with patch(
        "app.services.storage.count_application_media_references",
        side_effect=RuntimeError("Database query failed"),
    ):
        with patch("app.services.storage.delete_storage_object") as mock_delete:
            del_res = await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent_headers)
            # Withdrawal response is preserved
            assert del_res.status_code == 204

            # MinIO deletion must NEVER be called when reference query fails
            mock_delete.assert_not_called()


# ==============================================================================
# 16. Relative Keys and Full MinIO URLs Treated as Same Reference
# ==============================================================================

@pytest.mark.asyncio
async def test_relative_key_and_full_url_match_same_reference(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """16. Relative object keys and full MinIO URLs resolving to the same key are treated as the same reference."""
    _, proj_id, opp1_id = await setup_opportunity(async_client, ph_headers, status="open")
    opp2_id = await add_second_opportunity(async_client, ph_headers, proj_id)

    raw_key = f"media/{talent_user_id}/{uuid.uuid4()}/canonical_check.pdf"
    full_url = f"{settings.public_storage_endpoint}/{settings.MINIO_PRIVATE_BUCKET}/{raw_key}"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        # App 1 uses raw relative key
        res1 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp1_id), "resume_url": raw_key},
        )
        assert res1.status_code == 201
        app1_id = res1.json()["id"]

        # App 2 uses full URL
        res2 = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp2_id), "resume_url": full_url},
        )
        assert res2.status_code == 201

    with patch("app.services.storage.delete_storage_object") as mock_delete:
        del_res = await async_client.delete(f"/api/v1/applications/{app1_id}", headers=talent_headers)
        assert del_res.status_code == 204

        # Full URL in App 2 matches canonical key; object must be retained
        mock_delete.assert_not_called()


# ==============================================================================
# 17. Duplicate URLs in One Cleanup Request Processed Only Once
# ==============================================================================

@pytest.mark.asyncio
async def test_duplicate_urls_in_cleanup_processed_once(
    test_db_session: AsyncSession,
    talent_user_id: UUID,
):
    """17. Duplicate URLs in one cleanup request are processed only once."""
    raw_key = f"media/{talent_user_id}/{uuid.uuid4()}/dup_doc.pdf"
    full_url = f"{settings.public_storage_endpoint}/{settings.MINIO_PRIVATE_BUCKET}/{raw_key}"

    # List contains duplicates of raw key and full URL pointing to the same canonical key
    urls = [raw_key, raw_key, full_url, full_url]

    mock_s3 = MagicMock()
    mock_s3.delete_object.return_value = {"ResponseMetadata": {"HTTPStatusCode": 204}}

    deleted_keys = await cleanup_unreferenced_application_media(
        db=test_db_session,
        urls_to_check=urls,
        s3_client=mock_s3,
    )

    # Must be processed and deleted exactly once
    assert deleted_keys == [raw_key]
    assert mock_s3.delete_object.call_count == 1
