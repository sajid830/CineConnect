import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_test_token, verify_supabase_jwt
from app.models.user import User


@pytest.mark.asyncio
async def test_verify_supabase_jwt_success():
    """Verifies that a valid Supabase JWT is successfully parsed and claims extracted."""
    test_uid = uuid.uuid4()
    token = create_test_token(
        user_id=test_uid,
        email="talent@cineconnect.com",
        role="talent",
        extra_claims={"user_metadata": {"full_name": "Test Actor", "account_type": "talent"}},
    )

    payload = verify_supabase_jwt(token)
    assert payload is not None
    assert payload["sub"] == str(test_uid)
    assert payload["email"] == "talent@cineconnect.com"
    assert payload["user_metadata"]["account_type"] == "talent"


@pytest.mark.asyncio
async def test_verify_supabase_jwt_tampered_fails():
    """Verifies that any tampered token signature is rejected."""
    test_uid = uuid.uuid4()
    token = create_test_token(user_id=test_uid)
    # Tamper with the payload segment
    parts = token.split(".")
    tampered_token = f"{parts[0]}.eyJzdWIiOiAibWFsaWNpb3VzIn0.{parts[2]}"

    payload = verify_supabase_jwt(tampered_token)
    assert payload is None


@pytest.mark.asyncio
async def test_verify_supabase_jwt_expired_fails():
    """Verifies that an expired token is rejected."""
    test_uid = uuid.uuid4()
    token = create_test_token(user_id=test_uid, expires_in_seconds=-10)

    payload = verify_supabase_jwt(token)
    assert payload is None


@pytest.mark.asyncio
async def test_unauthenticated_request_rejected(async_client: AsyncClient):
    """Verifies that protected endpoints reject requests without a Supabase Bearer token."""
    response = await async_client.get("/api/v1/users/me")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_authenticated_supabase_syncs_to_postgresql(
    async_client: AsyncClient, test_db_session: AsyncSession
):
    """Verifies that a valid Supabase Auth JWT automatically provisions a matching
    PostgreSQL user record referencing the Supabase user UUID as primary key."""
    test_uid = uuid.uuid4()
    email = f"user_{test_uid.hex[:8]}@cineconnect.com"
    token = create_test_token(
        user_id=test_uid,
        email=email,
        role="talent",
        extra_claims={"user_metadata": {"full_name": "Supabase Talent", "account_type": "talent"}},
    )

    response = await async_client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(test_uid)
    assert data["email"] == email
    assert data["account_type"] == "talent"

    # Verify directly in local PostgreSQL/SQLite database
    stmt = select(User).where(User.id == test_uid)
    result = await test_db_session.execute(stmt)
    db_user = result.scalar_one_or_none()
    assert db_user is not None
    assert db_user.id == test_uid
    assert db_user.email == email

