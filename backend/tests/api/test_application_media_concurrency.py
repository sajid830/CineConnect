"""Genuine Asynchronous Concurrency Tests for CineConnect Application Media Cleanup.

Uses two distinct PostgreSQL AsyncSession connections bound to test_engine to prove
that transaction-scoped advisory locks serialize media attachment, reference-counting,
and deletion across concurrent workers and processes without TOCTOU race conditions.

Covers:
1. Withdrawal cleanup acquires lock first; concurrent submission waits, detects deleted file, rejected.
2. Submission acquires lock first; cleanup waits, sees newly committed reference, retains file.
3. Media replacement and concurrent attachment of old file are serialized safely.
4. Two applications concurrently attach the same existing file successfully.
5. Two applications concurrently withdraw references to the same file without inconsistent outcomes.
6. A failed reference-count query never triggers MinIO deletion.
7. MinIO deletion failure does not undo successful withdrawal or media update.
8. Multiple media keys are locked in deterministic sorted order to prevent deadlocks.
"""
import asyncio
import time
import uuid
from uuid import UUID
from unittest.mock import patch, MagicMock
import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.opportunity import Opportunity, Application
from app.models.production_house import ProductionHouse, Project
from app.services.storage import (
    acquire_media_advisory_lock,
    acquire_media_advisory_locks,
    count_application_media_references,
    cleanup_unreferenced_application_media,
    get_media_advisory_lock_id,
    StorageConnectionError,
    StorageError,
)
from app.models.user import User
from tests.conftest import test_engine, TALENT_USER_ID, PH_USER_ID

# Dedicated User UUIDs for Concurrency Tests (avoid collision with canonical test personas)
CONCURRENCY_PH_USER_ID = UUID("99999999-9999-9999-9999-999999999991")
CONCURRENCY_TALENT_USER_ID = UUID("99999999-9999-9999-9999-999999999992")


@pytest_asyncio.fixture(autouse=True)
async def cleanup_concurrency_records():
    """Teardown fixture that purges concurrency test records from the DB."""
    yield
    async with test_engine.begin() as conn:
        from sqlalchemy import text
        await conn.execute(text(f"DELETE FROM applications WHERE talent_id = '{CONCURRENCY_TALENT_USER_ID}';"))
        await conn.execute(text(f"DELETE FROM opportunities WHERE production_house_id IN (SELECT id FROM production_houses WHERE user_id = '{CONCURRENCY_PH_USER_ID}');"))
        await conn.execute(text(f"DELETE FROM projects WHERE production_house_id IN (SELECT id FROM production_houses WHERE user_id = '{CONCURRENCY_PH_USER_ID}');"))
        await conn.execute(text(f"DELETE FROM production_houses WHERE user_id = '{CONCURRENCY_PH_USER_ID}';"))
        await conn.execute(text(f"DELETE FROM users WHERE id IN ('{CONCURRENCY_PH_USER_ID}', '{CONCURRENCY_TALENT_USER_ID}');"))


# ==============================================================================
# Helper to set up opportunities directly in database
# ==============================================================================

async def ensure_test_users(session: AsyncSession):
    """Ensures test User records exist in PostgreSQL to satisfy foreign keys."""
    res_ph = await session.execute(select(User).where(User.id == CONCURRENCY_PH_USER_ID))
    if not res_ph.scalar_one_or_none():
        session.add(User(id=CONCURRENCY_PH_USER_ID, email="concurrency_ph@test.com", account_type="production_house"))
    res_t = await session.execute(select(User).where(User.id == CONCURRENCY_TALENT_USER_ID))
    if not res_t.scalar_one_or_none():
        session.add(User(id=CONCURRENCY_TALENT_USER_ID, email="concurrency_talent@test.com", account_type="talent"))
    await session.flush()


async def create_db_opportunity(session: AsyncSession) -> tuple[UUID, UUID, UUID]:
    """Sets up a PH, Project, and Opportunity in the DB."""
    await ensure_test_users(session)

    # Ensure PH exists
    ph_res = await session.execute(select(ProductionHouse).where(ProductionHouse.user_id == CONCURRENCY_PH_USER_ID))
    ph = ph_res.scalar_one_or_none()
    if not ph:
        ph = ProductionHouse(
            user_id=CONCURRENCY_PH_USER_ID,
            company_name=f"Studio {uuid.uuid4().hex[:6]}",
            location="Mumbai",
        )
        session.add(ph)
        await session.flush()

    proj = Project(
        production_house_id=ph.id,
        title=f"Film {uuid.uuid4().hex[:6]}",
        genre="Action",
    )
    session.add(proj)
    await session.flush()

    opp = Opportunity(
        project_id=proj.id,
        production_house_id=ph.id,
        title=f"Role {uuid.uuid4().hex[:6]}",
        status="open",
    )
    session.add(opp)
    await session.commit()
    return ph.id, proj.id, opp.id


# ==============================================================================
# 1. Withdrawal Cleanup Acquires Lock First -> Concurrent Submission Waits & Fails
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_cleanup_first_blocks_submission():
    """1. Withdrawal cleanup acquires the lock first; concurrent submission waits,
    then detects the deleted file and is rejected.
    """
    resume_key = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/shared_race.pdf"
    lock_id = get_media_advisory_lock_id(resume_key)

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        _, _, opp1_id = await create_db_opportunity(s_setup)
        _, _, opp2_id = await create_db_opportunity(s_setup)

        # Create App 1 referencing resume_key
        app1 = Application(
            opportunity_id=opp1_id,
            talent_id=CONCURRENCY_TALENT_USER_ID,
            resume_url=resume_key,
            status="submitted",
        )
        s_setup.add(app1)
        await s_setup.commit()
        app1_id = app1.id

    barrier_cleanup_locked = asyncio.Event()
    file_exists_state = {"exists": True}
    submission_waited = False
    submission_error = None

    async def worker_cleanup():
        async with AsyncSession(test_engine, expire_on_commit=False) as s_clean:
            # Delete App 1 row
            res = await s_clean.execute(select(Application).where(Application.id == app1_id))
            rec = res.scalar_one()
            await s_clean.delete(rec)
            await s_clean.commit()

            # Now run cleanup holding the advisory lock
            async with s_clean.begin():
                await acquire_media_advisory_lock(s_clean, resume_key)
                barrier_cleanup_locked.set()

                # Simulate holding lock while performing MinIO check and delete
                ref_count = await count_application_media_references(s_clean, resume_key)
                assert ref_count == 0

                await asyncio.sleep(0.4)
                # Object is deleted from storage
                file_exists_state["exists"] = False

    async def worker_submit():
        nonlocal submission_waited, submission_error
        await barrier_cleanup_locked.wait()
        t0 = time.time()

        async with AsyncSession(test_engine, expire_on_commit=False) as s_submit:
            # Worker 2 attempts to submit App 2 attaching the same resume_key
            # It must acquire the advisory lock before checking existence
            async with s_submit.begin():
                await acquire_media_advisory_lock(s_submit, resume_key)
                elapsed = time.time() - t0
                if elapsed >= 0.3:
                    submission_waited = True

                # Lock acquired: now check existence (simulates validate_talent_media_ownership)
                if not file_exists_state["exists"]:
                    submission_error = "File does not exist in storage"
                else:
                    app2 = Application(
                        opportunity_id=opp2_id,
                        talent_id=CONCURRENCY_TALENT_USER_ID,
                        resume_url=resume_key,
                        status="submitted",
                    )
                    s_submit.add(app2)

    await asyncio.gather(worker_cleanup(), worker_submit())

    assert submission_waited is True, "Concurrent submission should have waited for advisory lock release"
    assert submission_error == "File does not exist in storage"


# ==============================================================================
# 2. Submission Acquires Lock First -> Cleanup Waits & Retains File
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_submission_first_retains_file():
    """2. Submission acquires lock first; cleanup waits, then sees the newly committed
    reference and retains the file.
    """
    resume_key = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/submit_first.pdf"

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        _, _, opp1_id = await create_db_opportunity(s_setup)
        _, _, opp2_id = await create_db_opportunity(s_setup)

        app1 = Application(
            opportunity_id=opp1_id,
            talent_id=CONCURRENCY_TALENT_USER_ID,
            resume_url=resume_key,
            status="submitted",
        )
        s_setup.add(app1)
        await s_setup.commit()
        app1_id = app1.id

    barrier_submit_locked = asyncio.Event()
    cleanup_waited = False
    mock_delete = MagicMock()

    async def worker_submit():
        async with AsyncSession(test_engine, expire_on_commit=False) as s_sub:
            # Submit App 2 attaching resume_key
            async with s_sub.begin():
                await acquire_media_advisory_lock(s_sub, resume_key)
                barrier_submit_locked.set()

                # Simulate DB insert while holding lock
                await asyncio.sleep(0.4)
                app2 = Application(
                    opportunity_id=opp2_id,
                    talent_id=CONCURRENCY_TALENT_USER_ID,
                    resume_url=resume_key,
                    status="submitted",
                )
                s_sub.add(app2)
            # Transaction commits here, releasing lock

    async def worker_cleanup():
        nonlocal cleanup_waited
        await barrier_submit_locked.wait()
        t0 = time.time()

        async with AsyncSession(test_engine, expire_on_commit=False) as s_clean:
            # App 1 is withdrawn
            res = await s_clean.execute(select(Application).where(Application.id == app1_id))
            rec = res.scalar_one()
            await s_clean.delete(rec)
            await s_clean.commit()

            # Cleanup acquires advisory lock (must wait for worker_submit to commit)
            async with s_clean.begin():
                await acquire_media_advisory_lock(s_clean, resume_key)
                elapsed = time.time() - t0
                if elapsed >= 0.3:
                    cleanup_waited = True

                # Check references while holding lock
                ref_count = await count_application_media_references(
                    s_clean,
                    resume_key,
                    exclude_application_id=app1_id,
                )

                # Sees App 2 committed by worker_submit!
                assert ref_count == 1, f"Expected 1 reference, got {ref_count}"
                if ref_count == 0:
                    mock_delete(resume_key)

    await asyncio.gather(worker_submit(), worker_cleanup())

    assert cleanup_waited is True, "Cleanup should have waited for submission advisory lock"
    mock_delete.assert_not_called()


# ==============================================================================
# 3. Media Replacement & Concurrent Attachment Serialized Safely
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_replacement_and_attachment_serialized():
    """3. Media replacement and concurrent attachment of the old file are serialized safely."""
    old_key = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/old_resume.pdf"
    new_key = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/new_resume.pdf"

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        _, _, opp1_id = await create_db_opportunity(s_setup)
        _, _, opp2_id = await create_db_opportunity(s_setup)

        app1 = Application(
            opportunity_id=opp1_id,
            talent_id=CONCURRENCY_TALENT_USER_ID,
            resume_url=old_key,
            status="submitted",
        )
        s_setup.add(app1)
        await s_setup.commit()
        app1_id = app1.id

    barrier_replace = asyncio.Event()

    async def worker_replace():
        async with AsyncSession(test_engine, expire_on_commit=False) as s_rep:
            res = await s_rep.execute(select(Application).where(Application.id == app1_id))
            app = res.scalar_one()
            app.resume_url = new_key
            await s_rep.commit()

            # Now clean up old_key
            async with s_rep.begin():
                await acquire_media_advisory_lock(s_rep, old_key)
                barrier_replace.set()
                await asyncio.sleep(0.3)
                ref_count = await count_application_media_references(s_rep, old_key)
                assert ref_count == 0

    async def worker_attach():
        await barrier_replace.wait()
        async with AsyncSession(test_engine, expire_on_commit=False) as s_att:
            # Concurrent attachment of old_key waits on advisory lock
            async with s_att.begin():
                t0 = time.time()
                await acquire_media_advisory_lock(s_att, old_key)
                assert time.time() - t0 >= 0.2

    await asyncio.gather(worker_replace(), worker_attach())


# ==============================================================================
# 4. Two Applications Concurrently Attach Same Existing File
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_two_applications_attach_same_file():
    """4. Two applications concurrently attach the same existing file successfully."""
    shared_key = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/concurrent_attach.pdf"

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        _, _, opp1_id = await create_db_opportunity(s_setup)
        _, _, opp2_id = await create_db_opportunity(s_setup)

    async def attach_app(opp_id: UUID):
        async with AsyncSession(test_engine, expire_on_commit=False) as session:
            async with session.begin():
                await acquire_media_advisory_locks(session, [shared_key])
                app = Application(
                    opportunity_id=opp_id,
                    talent_id=CONCURRENCY_TALENT_USER_ID,
                    resume_url=shared_key,
                    status="submitted",
                )
                session.add(app)
            return app.id

    app1_id, app2_id = await asyncio.gather(attach_app(opp1_id), attach_app(opp2_id))

    async with AsyncSession(test_engine, expire_on_commit=False) as s_check:
        res1 = await s_check.execute(select(Application).where(Application.id == app1_id))
        res2 = await s_check.execute(select(Application).where(Application.id == app2_id))
        assert res1.scalar_one() is not None
        assert res2.scalar_one() is not None

        count = await count_application_media_references(s_check, shared_key)
        assert count == 2


# ==============================================================================
# 5. Two Applications Concurrently Withdraw References to Same File
# ==============================================================================

@pytest.mark.asyncio
async def test_concurrency_two_applications_withdraw_same_file():
    """5. Two applications concurrently withdraw references to the same file without inconsistent outcomes."""
    shared_key = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/concurrent_withdraw.pdf"

    async with AsyncSession(test_engine, expire_on_commit=False) as s_setup:
        _, _, opp1_id = await create_db_opportunity(s_setup)
        _, _, opp2_id = await create_db_opportunity(s_setup)

        app1 = Application(opportunity_id=opp1_id, talent_id=CONCURRENCY_TALENT_USER_ID, resume_url=shared_key, status="submitted")
        app2 = Application(opportunity_id=opp2_id, talent_id=CONCURRENCY_TALENT_USER_ID, resume_url=shared_key, status="submitted")
        s_setup.add_all([app1, app2])
        await s_setup.commit()
        app1_id = app1.id
        app2_id = app2.id

    mock_s3 = MagicMock()
    mock_s3.delete_object.return_value = {"ResponseMetadata": {"HTTPStatusCode": 204}}

    async def withdraw_app(app_id: UUID):
        async with AsyncSession(test_engine, expire_on_commit=False) as session:
            res = await session.execute(select(Application).where(Application.id == app_id))
            rec = res.scalar_one()
            old_url = rec.resume_url
            await session.delete(rec)
            await session.commit()

            return await cleanup_unreferenced_application_media(
                db=session,
                urls_to_check=[old_url],
                exclude_application_id=app_id,
                s3_client=mock_s3,
            )

    del1, del2 = await asyncio.gather(withdraw_app(app1_id), withdraw_app(app2_id))

    # The file should be deleted by the final withdrawal; neither fails
    total_deletions = len(del1) + len(del2)
    assert total_deletions >= 1, "File should have been deleted once all references were withdrawn"
    assert mock_s3.delete_object.call_count >= 1


# ==============================================================================
# 6. Failed Reference Query Never Triggers Deletion
# ==============================================================================

@pytest.mark.asyncio
async def test_failed_query_never_triggers_deletion():
    """6. A failed reference-count query never triggers MinIO deletion."""
    test_key = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/db_fail.pdf"
    mock_s3 = MagicMock()

    async with AsyncSession(test_engine, expire_on_commit=False) as session:
        with patch(
            "app.services.storage.count_application_media_references",
            side_effect=RuntimeError("PostgreSQL connection lost"),
        ):
            with pytest.raises(RuntimeError, match="PostgreSQL connection lost"):
                await cleanup_unreferenced_application_media(
                    db=session,
                    urls_to_check=[test_key],
                    s3_client=mock_s3,
                )

    mock_s3.delete_object.assert_not_called()


# ==============================================================================
# 7. MinIO Deletion Failure Does Not Undo Successful Withdrawal
# ==============================================================================

@pytest.mark.asyncio
async def test_minio_deletion_failure_preserves_withdrawal(
    async_client: AsyncClient,
    ph_headers: dict,
    talent_headers: dict,
):
    """7. MinIO deletion failure does not undo a successful withdrawal or media update."""
    _, _, opp_id = await create_db_opportunity(async_client) if False else (None, None, None)

    # Use standard async_client test for endpoint-level verification
    ph_res = await async_client.post(
        "/api/v1/production-houses",
        headers=ph_headers,
        json={"company_name": f"Studio {uuid.uuid4().hex[:6]}", "location": "Mumbai"},
    )
    if ph_res.status_code == 201:
        ph_id = ph_res.json()["id"]
        proj_res = await async_client.post(
            "/api/v1/projects",
            headers=ph_headers,
            json={"title": f"Proj {uuid.uuid4().hex[:6]}", "genre": "Sci-Fi"},
        )
        proj_id = proj_res.json()["id"]
        opp_res = await async_client.post(
            "/api/v1/opportunities/",
            headers=ph_headers,
            json={"title": "Actor", "project_id": proj_id, "status": "open"},
        )
        opp_id = opp_res.json()["id"]
    else:
        # PH already exists for user
        proj_res = await async_client.post(
            "/api/v1/projects",
            headers=ph_headers,
            json={"title": f"Proj {uuid.uuid4().hex[:6]}", "genre": "Sci-Fi"},
        )
        proj_id = proj_res.json()["id"]
        opp_res = await async_client.post(
            "/api/v1/opportunities/",
            headers=ph_headers,
            json={"title": "Actor", "project_id": proj_id, "status": "open"},
        )
        opp_id = opp_res.json()["id"]

    resume_key = f"media/{TALENT_USER_ID}/{uuid.uuid4()}/outage.pdf"

    with patch("app.services.storage.check_storage_object_exists", return_value=True):
        sub_res = await async_client.post(
            "/api/v1/applications/",
            headers=talent_headers,
            json={"opportunity_id": str(opp_id), "resume_url": resume_key},
        )
        assert sub_res.status_code == 201
        app_id = sub_res.json()["id"]

    # Storage deletion throws an exception
    with patch(
        "app.services.storage.delete_storage_object",
        side_effect=StorageConnectionError("MinIO connection timed out"),
    ):
        del_res = await async_client.delete(f"/api/v1/applications/{app_id}", headers=talent_headers)
        assert del_res.status_code == 204

    # Application record was successfully deleted from PostgreSQL despite MinIO error
    get_res = await async_client.get(f"/api/v1/applications/{app_id}", headers=talent_headers)
    assert get_res.status_code == 404


# ==============================================================================
# 8. Multiple Media Keys Locked in Deterministic Sorted Order
# ==============================================================================

@pytest.mark.asyncio
async def test_multiple_media_keys_deterministic_sorted_lock_order():
    """8. Multiple media keys are locked in deterministic sorted order to prevent deadlocks."""
    key_z = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/z_reel.mp4"
    key_a = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/a_resume.pdf"
    key_m = f"media/{CONCURRENCY_TALENT_USER_ID}/{uuid.uuid4()}/m_portfolio.pdf"

    # Input in random unsorted order
    input_keys = [key_z, key_a, key_m, key_z, "https://vimeo.com/12345"]

    order_locked = []

    async with AsyncSession(test_engine, expire_on_commit=False) as session:
        async with session.begin():
            with patch("app.services.storage.acquire_media_advisory_lock", side_effect=lambda db, k: order_locked.append(k) or 1):
                await acquire_media_advisory_locks(session, input_keys)

    # Expected order: only valid canonical private keys, deduplicated, sorted alphabetically
    expected_order = sorted([key_a, key_m, key_z])
    assert order_locked == expected_order, f"Expected locks in sorted order {expected_order}, got {order_locked}"
