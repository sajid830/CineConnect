import asyncio
import uuid
from uuid import UUID
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi.security import HTTPAuthorizationCredentials

from app.core.security import create_test_token
from app.api.dependencies import get_current_user
from app.models.user import User
from tests.conftest import test_engine


@pytest.mark.asyncio
async def test_unauthenticated_user_access_rejected(async_client: AsyncClient):
    """Verifies that accessing protected user endpoints without credentials returns 401 or 403."""
    response = await async_client.get("/api/v1/users/me")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_invalid_token_rejected(async_client: AsyncClient, invalid_headers: dict):
    """Verifies that accessing protected user endpoints with a malformed token returns 401."""
    response = await async_client.get("/api/v1/users/me", headers=invalid_headers)
    assert response.status_code == 401
    assert "Invalid or expired" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_expired_token_rejected(async_client: AsyncClient, expired_headers: dict):
    """Verifies that accessing protected user endpoints with an expired token returns 401."""
    response = await async_client.get("/api/v1/users/me", headers=expired_headers)
    assert response.status_code == 401
    assert "Invalid or expired" in response.json().get("detail", "")


@pytest.mark.asyncio
async def test_talent_user_profile_sync_and_retrieval(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies that an authenticated Supabase user is automatically synchronized and retrieved."""
    response = await async_client.get("/api/v1/users/me", headers=talent_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(talent_user_id)
    assert data["email"] == "talent@testcineconnect.com"
    assert data["account_type"] == "talent"
    assert data["full_name"] == "Test Talent User"
    assert data["is_verified"] is False
    assert data["experience_years"] == 0


@pytest.mark.asyncio
async def test_update_talent_user_profile(
    async_client: AsyncClient,
    talent_headers: dict,
    talent_user_id: UUID,
):
    """Verifies updating talent profile fields."""
    # First sync user
    await async_client.get("/api/v1/users/me", headers=talent_headers)

    update_payload = {
        "full_name": "Updated Talent Name",
        "role": "Cinematographer",
        "location": "Mumbai, India",
        "bio": "Specialized in anamorphic cinematography and visual storytelling.",
        "phone": "+919876543210",
        "experience_years": 7,
        "skills": ["Cinematography", "Lighting", "Drone Operation"],
    }
    response = await async_client.put(
        "/api/v1/users/me",
        headers=talent_headers,
        json=update_payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(talent_user_id)
    assert data["full_name"] == "Updated Talent Name"
    assert data["role"] == "Cinematographer"
    assert data["experience_years"] == 7
    assert data["skills"] == ["Cinematography", "Lighting", "Drone Operation"]


# ==============================================================================
# Group 1 Identity Security & UUID Mapping Tests
# ==============================================================================

@pytest.mark.asyncio
async def test_different_uuid_same_email_rejected_with_409(async_client: AsyncClient):
    """1. Different UUID, same email: reject with HTTP 409 and preserve the original account."""
    original_uuid = uuid.uuid4()
    original_email = f"user_{original_uuid.hex[:12]}@test.com"
    token_1 = create_test_token(user_id=original_uuid, email=original_email, account_type="talent")

    # Provision original user
    res1 = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token_1}"})
    assert res1.status_code == 200
    assert res1.json()["id"] == str(original_uuid)
    assert res1.json()["email"] == original_email

    # Attempt to authenticate with a different UUID using the exact same email
    conflicting_uuid = uuid.uuid4()
    token_2 = create_test_token(user_id=conflicting_uuid, email=original_email, account_type="talent")

    res2 = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token_2}"})
    assert res2.status_code == 409
    assert "already exists" in res2.json().get("detail", "")

    # Verify original account remains untouched and still authenticates
    res3 = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token_1}"})
    assert res3.status_code == 200
    assert res3.json()["id"] == str(original_uuid)


@pytest.mark.asyncio
async def test_existing_matching_uuid_authenticated_without_modification(async_client: AsyncClient):
    """2. Existing matching UUID: authenticate successfully without modifying the existing record."""
    user_id = uuid.uuid4()
    original_email = f"user_{user_id.hex[:12]}@test.com"
    token_1 = create_test_token(user_id=user_id, email=original_email, account_type="talent")

    res1 = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token_1}"})
    assert res1.status_code == 200

    # Present token with different metadata or email for the SAME UUID
    token_2 = create_test_token(
        user_id=user_id,
        email="changed_email@test.com",
        account_type="production_house",
        extra_claims={"user_metadata": {"full_name": "Tampered Name"}},
    )
    res2 = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token_2}"})
    assert res2.status_code == 200
    data = res2.json()
    assert data["id"] == str(user_id)
    assert data["email"] == original_email  # Not silently updated
    assert data["account_type"] == "talent"  # Not silently changed


@pytest.mark.asyncio
async def test_new_uuid_provisioned_with_exact_uuid(async_client: AsyncClient):
    """3. New UUID: provision a local user with the exact UUID."""
    new_uuid = uuid.uuid4()
    new_email = f"fresh_{new_uuid.hex[:12]}@test.com"
    token = create_test_token(user_id=new_uuid, email=new_email, account_type="talent")

    res = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == str(new_uuid)
    assert data["email"] == new_email
    assert data["account_type"] == "talent"


@pytest.mark.asyncio
async def test_missing_email_generates_synthetic_email_full_uuid(async_client: AsyncClient):
    """4. Missing email: generate a synthetic email using the full UUID."""
    user_id = uuid.uuid4()
    # Create token with empty or absent email
    token = create_test_token(user_id=user_id, email="", account_type="talent")

    res = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == str(user_id)
    expected_synthetic_email = f"user_{user_id.hex}@cineconnect.com"
    assert data["email"] == expected_synthetic_email
    # Must use full 32-character hex representation, not just 8 chars
    assert len(user_id.hex) == 32
    assert user_id.hex in data["email"]


@pytest.mark.asyncio
async def test_two_uuids_same_first_eight_chars_provision_independently(async_client: AsyncClient):
    """5. Two UUIDs sharing the same first eight characters: provision independently when no email claim is supplied."""
    prefix = "12345678"
    uuid_1 = uuid.UUID(f"{prefix}-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    uuid_2 = uuid.UUID(f"{prefix}-bbbb-4bbb-8bbb-bbbbbbbbbbbb")

    token_1 = create_test_token(user_id=uuid_1, email="", account_type="talent")
    token_2 = create_test_token(user_id=uuid_2, email="", account_type="talent")

    res1 = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token_1}"})
    assert res1.status_code == 200
    assert res1.json()["id"] == str(uuid_1)
    assert res1.json()["email"] == f"user_{uuid_1.hex}@cineconnect.com"

    res2 = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token_2}"})
    assert res2.status_code == 200
    assert res2.json()["id"] == str(uuid_2)
    assert res2.json()["email"] == f"user_{uuid_2.hex}@cineconnect.com"

    assert res1.json()["email"] != res2.json()["email"]


@pytest.mark.asyncio
async def test_public_signup_cannot_self_assign_admin(async_client: AsyncClient):
    """6. Public signup cannot self-assign admin."""
    user_id = uuid.uuid4()
    token = create_test_token(
        user_id=user_id,
        email=f"attacker_{user_id.hex[:12]}@test.com",
        account_type="admin",
        role="admin",
        extra_claims={"user_metadata": {"account_type": "admin", "role": "admin"}},
    )

    res = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == str(user_id)
    # Must fall back to 'talent'
    assert data["account_type"] == "talent"
    assert data["account_type"] != "admin"


@pytest.mark.asyncio
async def test_public_production_house_provisioning_works(async_client: AsyncClient):
    """7. Public Production House provisioning still works."""
    user_id = uuid.uuid4()
    token = create_test_token(
        user_id=user_id,
        email=f"producer_{user_id.hex[:12]}@test.com",
        account_type="production_house",
        role="production_house",
        extra_claims={"user_metadata": {"account_type": "production_house", "full_name": "Studio Chief"}},
    )

    res = await async_client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == str(user_id)
    assert data["account_type"] == "production_house"
    assert data["full_name"] == "Studio Chief"


@pytest.mark.asyncio
async def test_concurrent_jit_provisioning_independent_sessions():
    """8. Concurrent JIT provisioning: use independent database sessions,
    verify one user record is created, and verify all successful requests resolve to the same UUID.
    """
    new_uuid = uuid.uuid4()
    email = f"concurrent_{new_uuid.hex[:12]}@test.com"
    token = create_test_token(
        user_id=new_uuid,
        email=email,
        account_type="talent",
        extra_claims={"user_metadata": {"full_name": "Concurrent User"}},
    )
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)

    async def worker_provision():
        async with AsyncSession(test_engine, expire_on_commit=False) as s:
            return await get_current_user(credentials=creds, db=s)

    try:
        # Launch 5 concurrent provisioning requests across independent sessions
        results = await asyncio.gather(
            worker_provision(),
            worker_provision(),
            worker_provision(),
            worker_provision(),
            worker_provision(),
        )

        # Verify all successful resolutions point to the exact same UUID and email
        for user in results:
            assert user.id == new_uuid
            assert user.email == email
            assert user.account_type == "talent"

        # Verify exactly one record exists in the database
        async with AsyncSession(test_engine, expire_on_commit=False) as s_check:
            stmt = select(User).where(User.id == new_uuid)
            res = await s_check.execute(stmt)
            users = res.scalars().all()
            assert len(users) == 1
    finally:
        # Clean up the test user from DB
        async with test_engine.begin() as conn:
            from sqlalchemy import text
            await conn.execute(text(f"DELETE FROM users WHERE id = '{new_uuid}';"))

