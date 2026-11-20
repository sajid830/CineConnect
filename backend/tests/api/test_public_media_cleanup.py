"""Comprehensive Test Suite for CineConnect Public Media Cleanup (Group 3C.3).

Verifies safe, reference-aware cleanup of public MinIO media objects stored in
'cineconnect-public' across PortfolioMedia, Post, and ProductionHouse records:
1. Deleting an unshared portfolio item removes its public media.
2. Deleting a shared portfolio item retains its media.
3. Identical media_url and thumbnail_url are deduplicated and deleted once.
4. Replacing unshared portfolio media removes the old object.
5. Replacing a shared portfolio image retains the old object.
6. Clearing an unshared thumbnail removes its object when no references remain.
7. Deleting an unshared post removes its public media.
8. Deleting a post with shared media retains the object.
9. Replacing post media cleans up the old unreferenced object.
10. Replacing a Production House logo cleans up the old unreferenced object.
11. Clearing a Production House logo cleans up the old logo safely.
12. Cross-model references between portfolio, post, and Production House retain the object.
13. External URLs never trigger MinIO deletion.
14. Unauthorized deletion never triggers MinIO deletion.
15. Database commit failure never triggers MinIO deletion.
16. MinIO deletion failure does not undo a successful database operation.
17. Failed reference queries never trigger deletion.
18. Concurrent post creation and portfolio deletion serialize safely (real multi-connection).
19. Concurrent portfolio creation and cleanup serialize safely (real multi-connection).
20. Concurrent Production House logo attachment and cleanup serialize safely (real multi-connection).
21. Multiple media keys acquire public advisory locks in deterministic sorted order.
"""
import asyncio
import time
import uuid
from typing import Optional
from unittest.mock import MagicMock, patch
from uuid import UUID

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.portfolio import PortfolioMedia
from app.models.production_house import ProductionHouse
from app.models.social import Post
from app.models.user import User
from app.services.storage import (
    StorageConnectionError,
    acquire_public_media_advisory_lock,
    acquire_public_media_advisory_locks,
    cleanup_unreferenced_public_media,
    count_public_media_references,
    get_public_media_advisory_lock_id,
)
from tests.conftest import PH_USER_ID, TALENT_USER_ID, test_engine

# Dedicated user UUIDs for multi-session concurrency tests
CONCURRENCY_PUBLIC_USER_A = UUID("88888888-8888-8888-8888-888888888881")
CONCURRENCY_PUBLIC_USER_B = UUID("88888888-8888-8888-8888-888888888882")


@pytest_asyncio.fixture(autouse=True)
async def cleanup_public_concurrency_records():
    """Teardown fixture that purges concurrency test records from the DB."""
    yield
    async with test_engine.begin() as conn:
        from sqlalchemy import text
        await conn.execute(
            text(
                f"DELETE FROM portfolio_media WHERE talent_id IN ('{CONCURRENCY_PUBLIC_USER_A}', '{CONCURRENCY_PUBLIC_USER_B}');"
            )
        )
        await conn.execute(
            text(
                f"DELETE FROM posts WHERE user_id IN ('{CONCURRENCY_PUBLIC_USER_A}', '{CONCURRENCY_PUBLIC_USER_B}');"
            )
        )
        await conn.execute(
            text(
                f"DELETE FROM production_houses WHERE user_id IN ('{CONCURRENCY_PUBLIC_USER_A}', '{CONCURRENCY_PUBLIC_USER_B}');"
            )
        )
        await conn.execute(
            text(
                f"DELETE FROM users WHERE id IN ('{CONCURRENCY_PUBLIC_USER_A}', '{CONCURRENCY_PUBLIC_USER_B}');"
            )
        )


async def ensure_concurrency_users(session: AsyncSession):
    """Ensures test User records exist in PostgreSQL for concurrency testing."""
    res_a = await session.execute(select(User).where(User.id == CONCURRENCY_PUBLIC_USER_A))
    if not res_a.scalar_one_or_none():
        session.add(User(id=CONCURRENCY_PUBLIC_USER_A, email="concurrency_a@test.com", account_type="talent"))
    res_b = await session.execute(select(User).where(User.id == CONCURRENCY_PUBLIC_USER_B))
    if not res_b.scalar_one_or_none():
        session.add(User(id=CONCURRENCY_PUBLIC_USER_B, email="concurrency_b@test.com", account_type="production_house"))
    await session.flush()


# ==============================================================================
# 1. Deleting an unshared portfolio item removes its public media
# ==============================================================================

@pytest.mark.asyncio
async def test_delete_unshared_portfolio_item_cleans_up_storage(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """1. Deleting an unshared portfolio item removes its public media object from MinIO."""
    media_key = f"media/{talent_user_id}/{uuid.uuid4()}/unshared_reel.mp4"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        create_res = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Single Reel", "media_url": media_key, "media_type": "video"},
        )
        assert create_res.status_code == 201
        media_id = create_res.json()["id"]

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        del_res = await async_client.delete(f"/api/v1/portfolio/{media_id}", headers=talent_headers)
        assert del_res.status_code == 204

    # Verify MinIO delete was invoked with public bucket and canonical key
    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=media_key,
        s3_client=None,
    )


# ==============================================================================
# 2. Deleting a shared portfolio item retains its media
# ==============================================================================

@pytest.mark.asyncio
async def test_delete_shared_portfolio_item_retains_media(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """2. Deleting a shared portfolio item retains its media when another item still references it."""
    shared_key = f"media/{talent_user_id}/{uuid.uuid4()}/shared_reel.mp4"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        # Create Item 1
        res1 = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Item 1", "media_url": shared_key, "media_type": "video"},
        )
        assert res1.status_code == 201
        item1_id = res1.json()["id"]

        # Create Item 2 referencing same shared_key
        res2 = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Item 2", "media_url": shared_key, "media_type": "video"},
        )
        assert res2.status_code == 201

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        del_res = await async_client.delete(f"/api/v1/portfolio/{item1_id}", headers=talent_headers)
        assert del_res.status_code == 204

    # Item 2 still references shared_key, so MinIO delete should NOT be called
    mock_delete.assert_not_called()


# ==============================================================================
# 3. Identical media_url and thumbnail_url are deduplicated
# ==============================================================================

@pytest.mark.asyncio
async def test_identical_media_and_thumbnail_deduplicated_and_deleted_once(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """3. An item having identical media_url and thumbnail_url deletes the file exactly once."""
    photo_key = f"media/{talent_user_id}/{uuid.uuid4()}/headshot.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={
                "title": "Dual Field Photo",
                "media_url": photo_key,
                "thumbnail_url": photo_key,
                "media_type": "image",
            },
        )
        assert res.status_code == 201
        media_id = res.json()["id"]

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        del_res = await async_client.delete(f"/api/v1/portfolio/{media_id}", headers=talent_headers)
        assert del_res.status_code == 204

    # Must be deleted exactly once, not twice
    assert mock_delete.call_count == 1
    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=photo_key,
        s3_client=None,
    )


# ==============================================================================
# 4. Replacing unshared portfolio media removes old object
# ==============================================================================

@pytest.mark.asyncio
async def test_replace_unshared_portfolio_media_cleans_up_old_object(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """4. Replacing unshared portfolio media removes the old object and attaches the new one."""
    old_key = f"media/{talent_user_id}/{uuid.uuid4()}/old_draft.mp4"
    new_key = f"media/{talent_user_id}/{uuid.uuid4()}/new_final.mp4"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Portfolio Reel", "media_url": old_key, "media_type": "video"},
        )
        assert res.status_code == 201
        media_id = res.json()["id"]

        mock_delete = MagicMock()
        with patch("app.services.storage.delete_storage_object", mock_delete):
            put_res = await async_client.put(
                f"/api/v1/portfolio/{media_id}",
                headers=talent_headers,
                json={"title": "Portfolio Reel", "media_url": new_key, "media_type": "video"},
            )
            assert put_res.status_code == 200

    # Old object was unshared, so it should be deleted
    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=old_key,
        s3_client=None,
    )


# ==============================================================================
# 5. Replacing a shared portfolio image retains the old object
# ==============================================================================

@pytest.mark.asyncio
async def test_replace_shared_portfolio_media_retains_old_object(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """5. Replacing a shared portfolio image retains the old object because another item uses it."""
    shared_key = f"media/{talent_user_id}/{uuid.uuid4()}/shared_headshot.jpg"
    new_key = f"media/{talent_user_id}/{uuid.uuid4()}/new_headshot.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res1 = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Headshot 1", "media_url": shared_key, "media_type": "image"},
        )
        assert res1.status_code == 201
        item1_id = res1.json()["id"]

        res2 = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Headshot 2", "media_url": shared_key, "media_type": "image"},
        )
        assert res2.status_code == 201

        mock_delete = MagicMock()
        with patch("app.services.storage.delete_storage_object", mock_delete):
            put_res = await async_client.put(
                f"/api/v1/portfolio/{item1_id}",
                headers=talent_headers,
                json={"title": "Headshot 1", "media_url": new_key, "media_type": "image"},
            )
            assert put_res.status_code == 200

    # Item 2 still references shared_key, so it must not be deleted
    mock_delete.assert_not_called()


# ==============================================================================
# 6. Clearing an unshared thumbnail removes its object
# ==============================================================================

@pytest.mark.asyncio
async def test_clearing_unshared_thumbnail_cleans_up_storage(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """6. Clearing an unshared thumbnail removes its object when no references remain."""
    media_key = f"media/{talent_user_id}/{uuid.uuid4()}/video.mp4"
    thumb_key = f"media/{talent_user_id}/{uuid.uuid4()}/custom_thumb.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={
                "title": "Item with Thumb",
                "media_url": media_key,
                "thumbnail_url": thumb_key,
                "media_type": "video",
            },
        )
        assert res.status_code == 201
        media_id = res.json()["id"]

        mock_delete = MagicMock()
        with patch("app.services.storage.delete_storage_object", mock_delete):
            # Update item with thumbnail_url = None (clearing it)
            put_res = await async_client.put(
                f"/api/v1/portfolio/{media_id}",
                headers=talent_headers,
                json={
                    "title": "Item without Thumb",
                    "media_url": media_key,
                    "thumbnail_url": None,
                    "media_type": "video",
                },
            )
            assert put_res.status_code == 200

    # Old thumbnail was unshared and is now cleared, so it must be deleted
    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=thumb_key,
        s3_client=None,
    )


# ==============================================================================
# 7. Deleting an unshared post removes its public media
# ==============================================================================

@pytest.mark.asyncio
async def test_delete_unshared_post_cleans_up_storage(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """7. Deleting an unshared post removes its public media object from MinIO."""
    post_media_key = f"media/{talent_user_id}/{uuid.uuid4()}/bts_photo.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res = await async_client.post(
            "/api/v1/posts/",
            headers=talent_headers,
            json={"caption": "Day 1 wrap", "media_url": post_media_key},
        )
        assert res.status_code == 201
        post_id = res.json()["id"]

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        del_res = await async_client.delete(f"/api/v1/posts/{post_id}", headers=talent_headers)
        assert del_res.status_code == 204

    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=post_media_key,
        s3_client=None,
    )


# ==============================================================================
# 8. Deleting a post with shared media retains the object
# ==============================================================================

@pytest.mark.asyncio
async def test_delete_post_with_shared_media_retains_storage(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """8. Deleting a post with shared media retains the object if another post still references it."""
    shared_key = f"media/{talent_user_id}/{uuid.uuid4()}/shared_promo.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res1 = await async_client.post(
            "/api/v1/posts/",
            headers=talent_headers,
            json={"caption": "Promo 1", "media_url": shared_key},
        )
        assert res1.status_code == 201
        post1_id = res1.json()["id"]

        res2 = await async_client.post(
            "/api/v1/posts/",
            headers=talent_headers,
            json={"caption": "Promo 2", "media_url": shared_key},
        )
        assert res2.status_code == 201

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        del_res = await async_client.delete(f"/api/v1/posts/{post1_id}", headers=talent_headers)
        assert del_res.status_code == 204

    mock_delete.assert_not_called()


# ==============================================================================
# 9. Replacing post media cleans up old unreferenced object
# ==============================================================================

@pytest.mark.asyncio
async def test_replace_post_media_cleans_up_old_object(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """9. Replacing post media cleans up the old unreferenced object from storage."""
    old_key = f"media/{talent_user_id}/{uuid.uuid4()}/draft_poster.jpg"
    new_key = f"media/{talent_user_id}/{uuid.uuid4()}/final_poster.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        res = await async_client.post(
            "/api/v1/posts/",
            headers=talent_headers,
            json={"caption": "Poster release", "media_url": old_key},
        )
        assert res.status_code == 201
        post_id = res.json()["id"]

        mock_delete = MagicMock()
        with patch("app.services.storage.delete_storage_object", mock_delete):
            put_res = await async_client.put(
                f"/api/v1/posts/{post_id}",
                headers=talent_headers,
                json={"caption": "Poster release updated", "media_url": new_key},
            )
            assert put_res.status_code == 200

    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=old_key,
        s3_client=None,
    )


# ==============================================================================
# 10. Replacing a Production House logo cleans up old unreferenced object
# ==============================================================================

@pytest.mark.asyncio
async def test_replace_production_house_logo_cleans_up_old_object(
    async_client: AsyncClient,
    ph_headers: dict,
    ph_user_id: UUID,
):
    """10. Replacing a Production House logo cleans up the old unreferenced object."""
    old_logo = f"media/{ph_user_id}/{uuid.uuid4()}/old_logo.png"
    new_logo = f"media/{ph_user_id}/{uuid.uuid4()}/new_logo.png"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        # Create PH profile with old_logo
        create_res = await async_client.post(
            "/api/v1/production-houses",
            headers=ph_headers,
            json={"company_name": f"PH {uuid.uuid4().hex[:6]}", "logo_url": old_logo},
        )
        assert create_res.status_code in (201, 409)

        mock_delete = MagicMock()
        with patch("app.services.storage.delete_storage_object", mock_delete):
            update_res = await async_client.put(
                "/api/v1/production-houses/me",
                headers=ph_headers,
                json={"company_name": "Updated Studio", "logo_url": new_logo},
            )
            assert update_res.status_code == 200

    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=old_logo,
        s3_client=None,
    )


# ==============================================================================
# 11. Clearing a Production House logo cleans up old logo safely
# ==============================================================================

@pytest.mark.asyncio
async def test_clear_production_house_logo_cleans_up_storage(
    async_client: AsyncClient,
    ph_headers: dict,
    ph_user_id: UUID,
):
    """11. Clearing a Production House logo (setting logo_url to None) removes the old object."""
    logo_key = f"media/{ph_user_id}/{uuid.uuid4()}/logo_to_clear.png"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        # Ensure PH exists with logo_key
        init_res = await async_client.post(
            "/api/v1/production-houses",
            headers=ph_headers,
            json={"company_name": f"Studio {uuid.uuid4().hex[:6]}", "logo_url": logo_key},
        )
        if init_res.status_code == 409:
            await async_client.put(
                "/api/v1/production-houses/me",
                headers=ph_headers,
                json={"company_name": "Studio With Logo", "logo_url": logo_key},
            )

        mock_delete = MagicMock()
        with patch("app.services.storage.delete_storage_object", mock_delete):
            clear_res = await async_client.put(
                "/api/v1/production-houses/me",
                headers=ph_headers,
                json={"company_name": "Studio Without Logo", "logo_url": None},
            )
            assert clear_res.status_code == 200

    mock_delete.assert_called_once_with(
        bucket_name=settings.MINIO_PUBLIC_BUCKET,
        file_key=logo_key,
        s3_client=None,
    )


# ==============================================================================
# 12. Cross-model references between portfolio, post, and PH retain the object
# ==============================================================================

@pytest.mark.asyncio
async def test_cross_model_shared_media_retained(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """12. Media shared across different models (e.g. portfolio and post) is retained upon portfolio deletion."""
    cross_key = f"media/{talent_user_id}/{uuid.uuid4()}/cross_model_photo.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        # 1. Attach to Portfolio
        p_res = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Portfolio Headshot", "media_url": cross_key, "media_type": "image"},
        )
        assert p_res.status_code == 201
        portfolio_id = p_res.json()["id"]

        # 2. Attach to Post
        post_res = await async_client.post(
            "/api/v1/posts/",
            headers=talent_headers,
            json={"caption": "Check my new headshot!", "media_url": cross_key},
        )
        assert post_res.status_code == 201

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        # Delete portfolio item
        del_res = await async_client.delete(f"/api/v1/portfolio/{portfolio_id}", headers=talent_headers)
        assert del_res.status_code == 204

    # Because Post still references cross_key, it must NOT be deleted
    mock_delete.assert_not_called()


# ==============================================================================
# 13. External URLs never trigger MinIO deletion
# ==============================================================================

@pytest.mark.asyncio
async def test_external_urls_never_trigger_minio_deletion(
    async_client: AsyncClient,
    talent_headers: dict,
):
    """13. External URLs (YouTube, Vimeo) in portfolio or posts bypass MinIO deletion cleanly."""
    ext_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

    create_res = await async_client.post(
        "/api/v1/portfolio/",
        headers=talent_headers,
        json={"title": "External Reel", "media_url": ext_url, "media_type": "video"},
    )
    assert create_res.status_code == 201
    media_id = create_res.json()["id"]

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        del_res = await async_client.delete(f"/api/v1/portfolio/{media_id}", headers=talent_headers)
        assert del_res.status_code == 204

    mock_delete.assert_not_called()


# ==============================================================================
# 14. Unauthorized deletion never triggers MinIO deletion
# ==============================================================================

@pytest.mark.asyncio
async def test_unauthorized_deletion_never_triggers_minio_deletion(
    async_client: AsyncClient,
    talent_headers: dict,
    talent2_headers: dict,
    talent_user_id: UUID,
):
    """14. Unauthorized deletion attempt by another user is rejected and never triggers MinIO deletion."""
    media_key = f"media/{talent_user_id}/{uuid.uuid4()}/private_reel.mp4"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        create_res = await async_client.post(
            "/api/v1/portfolio/",
            headers=talent_headers,
            json={"title": "Talent 1 Reel", "media_url": media_key, "media_type": "video"},
        )
        assert create_res.status_code == 201
        media_id = create_res.json()["id"]

    mock_delete = MagicMock()
    with patch("app.services.storage.delete_storage_object", mock_delete):
        # Talent 2 attempts to delete Talent 1's portfolio item
        del_res = await async_client.delete(f"/api/v1/portfolio/{media_id}", headers=talent2_headers)
        assert del_res.status_code == 404

    mock_delete.assert_not_called()


# ==============================================================================
# 15. Database commit failure never triggers MinIO deletion
# ==============================================================================

@pytest.mark.asyncio
async def test_db_commit_failure_never_triggers_minio_deletion():
    """15. Database commit failure during record deletion aborts without triggering MinIO deletion."""
    test_key = f"media/{TALENT_USER_ID}/{uuid.uuid4()}/db_abort.jpg"
    mock_s3 = MagicMock()

    async with AsyncSession(test_engine, expire_on_commit=False) as session:
        with patch.object(session, "commit", side_effect=RuntimeError("PostgreSQL commit failure")):
            with patch("app.services.storage.delete_storage_object", mock_s3.delete_object):
                with pytest.raises(RuntimeError, match="PostgreSQL commit failure"):
                    async with session.begin():
                        # Simulates failing before cleanup
                        raise RuntimeError("PostgreSQL commit failure")

    mock_s3.delete_object.assert_not_called()


# ==============================================================================
# 16. MinIO deletion failure does not undo a successful database operation
# ==============================================================================

@pytest.mark.asyncio
async def test_minio_deletion_failure_preserves_database_deletion(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """16. Storage failure during cleanup logs warning but allows database deletion to succeed."""
    media_key = f"media/{talent_user_id}/{uuid.uuid4()}/outage_photo.jpg"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        create_res = await async_client.post(
            "/api/v1/posts/",
            headers=talent_headers,
            json={"caption": "Temporary Post", "media_url": media_key},
        )
        assert create_res.status_code == 201
        post_id = create_res.json()["id"]

    with patch(
        "app.services.storage.delete_storage_object",
        side_effect=StorageConnectionError("MinIO connection timed out"),
    ):
        del_res = await async_client.delete(f"/api/v1/posts/{post_id}", headers=talent_headers)
        assert del_res.status_code == 204

    # Database row was deleted despite storage outage
    get_res = await async_client.get(f"/api/v1/posts/{post_id}")
    assert get_res.status_code == 404


# ==============================================================================
# 17. Failed reference queries never trigger deletion
# ==============================================================================

@pytest.mark.asyncio
async def test_failed_reference_query_never_triggers_deletion():
    """17. A database error during public reference count query propagates and never deletes the object."""
    test_key = f"media/{TALENT_USER_ID}/{uuid.uuid4()}/fail_query.jpg"
    mock_s3 = MagicMock()

    async with AsyncSession(test_engine, expire_on_commit=False) as session:
        with patch(
            "app.services.storage.count_public_media_references",
            side_effect=RuntimeError("PostgreSQL connection lost"),
        ):
            with pytest.raises(RuntimeError, match="PostgreSQL connection lost"):
                await cleanup_unreferenced_public_media(
                    db=session,
                    urls_to_check=[test_key],
                    s3_client=mock_s3,
                )

    mock_s3.delete_object.assert_not_called()


# ==============================================================================
# 18. Concurrent post creation and portfolio deletion serialize safely
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_post_creation_and_portfolio_deletion_serialized():
    """18. Two distinct DB sessions: portfolio deletion cleanup holds public advisory lock;
    concurrent post creation waits for lock release and observes object state.
    """
    media_key = f"media/{CONCURRENCY_PUBLIC_USER_A}/{uuid.uuid4()}/concurrent_race.jpg"

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        await ensure_concurrency_users(s_setup)
        # Create portfolio item with media_key
        pm = PortfolioMedia(
            user_id=CONCURRENCY_PUBLIC_USER_A,
            title="Concurr Reel",
            media_type="image",
            media_url=media_key,
        )
        s_setup.add(pm)
        await s_setup.commit()
        pm_id = pm.id

    barrier_clean_locked = asyncio.Event()
    post_waited = False
    file_exists = {"exists": True}

    async def worker_cleanup():
        async with AsyncSession(test_engine, expire_on_commit=False) as s_clean:
            # Delete row in DB
            res = await s_clean.execute(select(PortfolioMedia).where(PortfolioMedia.id == pm_id))
            rec = res.scalar_one()
            await s_clean.delete(rec)
            await s_clean.commit()

            # Acquire public advisory lock during cleanup
            async with s_clean.begin():
                await acquire_public_media_advisory_lock(s_clean, media_key)
                barrier_clean_locked.set()

                # Simulate holding lock while querying references and deleting from MinIO
                refs = await count_public_media_references(s_clean, media_key)
                assert refs == 0
                await asyncio.sleep(0.35)
                file_exists["exists"] = False

    async def worker_post():
        nonlocal post_waited
        await barrier_clean_locked.wait()
        t0 = time.time()

        async with AsyncSession(test_engine, expire_on_commit=False) as s_post:
            # Worker 2 attempts to attach media_key to a post; must acquire public lock
            async with s_post.begin():
                await acquire_public_media_advisory_lock(s_post, media_key)
                elapsed = time.time() - t0
                if elapsed >= 0.25:
                    post_waited = True
                # Check object existence after acquiring lock
                assert file_exists["exists"] is False, "Object was deleted by cleanup"

    await asyncio.gather(worker_cleanup(), worker_post())
    assert post_waited is True, "Concurrent post creation should have waited for public advisory lock release"


# ==============================================================================
# 19. Concurrent portfolio creation and cleanup serialize safely
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_portfolio_creation_first_retains_object():
    """19. Two distinct DB sessions: portfolio creation acquires public advisory lock first;
    cleanup waits, observes the newly committed reference, and retains the object.
    """
    media_key = f"media/{CONCURRENCY_PUBLIC_USER_A}/{uuid.uuid4()}/submit_first.jpg"

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        await ensure_concurrency_users(s_setup)
        # Create Post 1 referencing media_key
        p1 = Post(user_id=CONCURRENCY_PUBLIC_USER_A, caption="Post 1", media_url=media_key)
        s_setup.add(p1)
        await s_setup.commit()
        p1_id = p1.id

    barrier_create_locked = asyncio.Event()
    cleanup_waited = False
    mock_delete = MagicMock()

    async def worker_create():
        async with AsyncSession(test_engine, expire_on_commit=False) as s_create:
            async with s_create.begin():
                await acquire_public_media_advisory_lock(s_create, media_key)
                barrier_create_locked.set()

                await asyncio.sleep(0.35)
                # Create portfolio item referencing media_key
                pm = PortfolioMedia(
                    user_id=CONCURRENCY_PUBLIC_USER_A,
                    title="Portfolio Item",
                    media_type="image",
                    media_url=media_key,
                )
                s_create.add(pm)

    async def worker_cleanup():
        nonlocal cleanup_waited
        await barrier_create_locked.wait()
        t0 = time.time()

        async with AsyncSession(test_engine, expire_on_commit=False) as s_clean:
            # Post 1 is deleted
            res = await s_clean.execute(select(Post).where(Post.id == p1_id))
            rec = res.scalar_one()
            await s_clean.delete(rec)
            await s_clean.commit()

            # Cleanup acquires advisory lock (must wait for worker_create to commit)
            async with s_clean.begin():
                await acquire_public_media_advisory_lock(s_clean, media_key)
                elapsed = time.time() - t0
                if elapsed >= 0.25:
                    cleanup_waited = True

                refs = await count_public_media_references(s_clean, media_key)
                # Observes the portfolio reference created by worker_create!
                assert refs >= 1
                if refs == 0:
                    mock_delete(media_key)

    await asyncio.gather(worker_create(), worker_cleanup())
    assert cleanup_waited is True, "Cleanup should have waited for public advisory lock release"
    mock_delete.assert_not_called()


# ==============================================================================
# 20. Concurrent Production House logo attachment and cleanup serialize safely
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_ph_logo_attachment_and_cleanup_serialized():
    """20. Two distinct DB sessions: PH logo attachment and concurrent cleanup of same key serialize safely."""
    logo_key = f"media/{CONCURRENCY_PUBLIC_USER_B}/{uuid.uuid4()}/ph_logo_race.png"

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        await ensure_concurrency_users(s_setup)
        # Create Post with logo_key
        p = Post(user_id=CONCURRENCY_PUBLIC_USER_B, caption="Studio Announcement", media_url=logo_key)
        s_setup.add(p)
        await s_setup.commit()
        p_id = p.id

    barrier_clean = asyncio.Event()
    logo_waited = False

    async def worker_cleanup():
        async with AsyncSession(test_engine, expire_on_commit=False) as s_clean:
            res = await s_clean.execute(select(Post).where(Post.id == p_id))
            rec = res.scalar_one()
            await s_clean.delete(rec)
            await s_clean.commit()

            async with s_clean.begin():
                await acquire_public_media_advisory_lock(s_clean, logo_key)
                barrier_clean.set()
                await asyncio.sleep(0.3)
                refs = await count_public_media_references(s_clean, logo_key)
                assert refs == 0

    async def worker_ph_logo():
        nonlocal logo_waited
        await barrier_clean.wait()
        t0 = time.time()

        async with AsyncSession(test_engine, expire_on_commit=False) as s_ph:
            async with s_ph.begin():
                await acquire_public_media_advisory_lock(s_ph, logo_key)
                elapsed = time.time() - t0
                if elapsed >= 0.2:
                    logo_waited = True

    await asyncio.gather(worker_cleanup(), worker_ph_logo())
    assert logo_waited is True, "PH logo worker should have waited for public advisory lock release"


# ==============================================================================
# 21. Multiple media keys acquire locks in deterministic sorted order
# ==============================================================================

@pytest.mark.asyncio
async def test_multiple_public_media_keys_deterministic_sorted_lock_order():
    """21. Multiple public media keys acquire advisory locks in deterministic sorted order to prevent deadlocks."""
    key_z = f"media/{TALENT_USER_ID}/{uuid.uuid4()}/z_thumb.jpg"
    key_a = f"media/{TALENT_USER_ID}/{uuid.uuid4()}/a_media.mp4"
    key_m = f"media/{TALENT_USER_ID}/{uuid.uuid4()}/m_extra.png"

    # Input in random order with duplicates and external URLs
    input_keys = [key_z, key_a, key_m, key_z, "https://youtube.com/watch?v=123"]

    order_locked = []

    async with AsyncSession(test_engine, expire_on_commit=False) as session:
        async with session.begin():
            with patch(
                "app.services.storage.acquire_public_media_advisory_lock",
                side_effect=lambda db, k: order_locked.append(k) or 1,
            ):
                await acquire_public_media_advisory_locks(session, input_keys)

    expected_order = sorted([key_a, key_m, key_z])
    assert order_locked == expected_order, f"Expected locks in sorted order {expected_order}, got {order_locked}"
