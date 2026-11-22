import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.db.session import get_db
from app.api.dependencies import get_current_user, require_talent, require_production_house
from app.models.user import User
from app.models.production_house import ProductionHouse
from app.schemas.production_house import ProductionHouseCreate
from app.api.v1.endpoints.production_houses import create_production_house


def create_mock_session() -> AsyncMock:
    """Creates a mock SQLAlchemy AsyncSession with synchronous and asynchronous operations correctly configured.

    In SQLAlchemy AsyncSession:
    - add, add_all: Synchronous operations (MagicMock)
    - execute, commit, rollback, refresh, flush, close: Asynchronous operations (AsyncMock)
    """
    session = AsyncMock()
    session.add = MagicMock()
    session.add_all = MagicMock()
    return session


@pytest.mark.asyncio
async def test_talent_metadata_provisioning():
    """1. Talent metadata mapping: user_metadata {'account_type': 'talent'} provisions Talent account."""
    user_id = uuid.uuid4()
    mock_payload = {
        "sub": str(user_id),
        "email": "talent@test.com",
        "user_metadata": {
            "account_type": "talent",
            "role": "talent",
            "full_name": "Jane Actor",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=mock_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="fake_token")
        user = await get_current_user(credentials=creds, db=mock_db)

        assert user.id == user_id
        assert user.email == "talent@test.com"
        assert user.account_type == "talent"
        assert user.full_name == "Jane Actor"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_production_house_metadata_provisioning():
    """2. Production House metadata mapping: user_metadata {'account_type': 'production_house'} provisions PH account."""
    user_id = uuid.uuid4()
    mock_payload = {
        "sub": str(user_id),
        "email": "studio@test.com",
        "user_metadata": {
            "account_type": "production_house",
            "role": "production",
            "full_name": "Studio Chief",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=mock_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="fake_token")
        user = await get_current_user(credentials=creds, db=mock_db)

        assert user.id == user_id
        assert user.email == "studio@test.com"
        assert user.account_type == "production_house"
        assert user.full_name == "Studio Chief"
        mock_db.add.assert_called_once()


@pytest.mark.asyncio
async def test_legacy_role_fallback_provisions_production_house():
    """3. Backward compatibility: when account_type is omitted but role='production' is present."""
    user_id = uuid.uuid4()
    mock_payload = {
        "sub": str(user_id),
        "email": "legacy_producer@test.com",
        "user_metadata": {
            "role": "production",
            "full_name": "Old School Producer",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=mock_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="fake_token")
        user = await get_current_user(credentials=creds, db=mock_db)

        assert user.account_type == "production_house"


@pytest.mark.asyncio
async def test_legacy_production_value_normalized():
    """4. Normalization: account_type='production' normalizes to 'production_house'."""
    user_id = uuid.uuid4()
    mock_payload = {
        "sub": str(user_id),
        "email": "prod_norm@test.com",
        "user_metadata": {
            "account_type": "production",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=mock_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="fake_token")
        user = await get_current_user(credentials=creds, db=mock_db)

        assert user.account_type == "production_house"


@pytest.mark.asyncio
async def test_untrusted_admin_falls_back_to_talent():
    """5. Security: untrusted account_type='admin' or unknown string safely defaults to 'talent'."""
    user_id = uuid.uuid4()
    mock_payload = {
        "sub": str(user_id),
        "email": "attacker@test.com",
        "user_metadata": {
            "account_type": "admin",
            "role": "admin",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=mock_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="fake_token")
        user = await get_current_user(credentials=creds, db=mock_db)

        assert user.account_type == "talent"
        assert user.account_type != "admin"


@pytest.mark.asyncio
async def test_existing_user_not_overwritten_on_subsequent_login():
    """6. Existing user: subsequent logins with tampered metadata do NOT mutate PostgreSQL record."""
    user_id = uuid.uuid4()
    existing_user = User(
        id=user_id,
        email="talent@test.com",
        account_type="talent",
        full_name="Original Talent",
    )

    mock_payload = {
        "sub": str(user_id),
        "email": "tampered_email@test.com",
        "user_metadata": {
            "account_type": "production_house",
            "full_name": "Tampered Name",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = existing_user
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=mock_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="fake_token")
        user = await get_current_user(credentials=creds, db=mock_db)

        assert user.id == user_id
        assert user.email == "talent@test.com"
        assert user.account_type == "talent"
        assert user.full_name == "Original Talent"
        mock_db.add.assert_not_called()


@pytest.mark.asyncio
async def test_talent_cannot_create_company_profile_asgi():
    """7. Security: An authenticated Talent account attempting to call POST /api/v1/production-houses receives HTTP 403."""
    user_id = uuid.uuid4()
    talent_user = User(
        id=user_id,
        email="talent@test.com",
        account_type="talent",
        full_name="Talent Actor",
    )

    mock_db = create_mock_session()

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return talent_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            payload = {
                "company_name": "Talent Unauthorized Studio",
                "description": "Attempting illegal role upgrade",
            }
            res = await client.post(
                "/api/v1/production-houses",
                headers={"Authorization": "Bearer dummy_token"},
                json=payload,
            )
            assert res.status_code == 403
            assert "restricted to Production House accounts" in res.json().get("detail", "")
            # Ensure the Talent user's account_type was NOT modified
            assert talent_user.account_type == "talent"
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_production_house_creates_company_profile_asgi():
    """8. Security & Onboarding: An authenticated Production House user creates company profile successfully via ASGI."""
    user_id = uuid.uuid4()
    ph_user = User(
        id=user_id,
        email="studio@test.com",
        account_type="production_house",
        full_name="Studio Chief",
        is_verified=False,
    )

    mock_db = create_mock_session()
    # Check existing profile query returns None (first creation)
    check_existing_result = MagicMock()
    check_existing_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = check_existing_result

    async def fake_refresh(instance):
        if not getattr(instance, "id", None):
            instance.id = uuid.uuid4()
        if not getattr(instance, "created_at", None):
            instance.created_at = datetime.now(timezone.utc)
        if not getattr(instance, "updated_at", None):
            instance.updated_at = datetime.now(timezone.utc)
        instance.user = ph_user

    mock_db.refresh.side_effect = fake_refresh

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return ph_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            payload = {
                "company_name": "Red Chillies VFX",
                "description": "Premier Visual Effects Studio",
                "location": "Mumbai, India",
                "specialization": "VFX",
                "website": "https://redchillies.com",
            }
            res = await client.post(
                "/api/v1/production-houses",
                headers={"Authorization": "Bearer dummy_token"},
                json=payload,
            )
            assert res.status_code == 201
            data = res.json()
            assert data["company_name"] == "Red Chillies VFX"
            assert data["user_id"] == str(user_id)
            assert data["is_verified"] is False
            assert "id" in data and data["id"] is not None
            assert "created_at" in data and data["created_at"] is not None
            assert "updated_at" in data and data["updated_at"] is not None
            assert ph_user.account_type == "production_house"
            mock_db.add.assert_called_once()
            mock_db.commit.assert_called_once()
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_production_house_duplicate_creation_returns_409_asgi():
    """9. Security & Constraint: An authenticated Production House user attempting to create a second profile receives HTTP 409."""
    user_id = uuid.uuid4()
    ph_user = User(
        id=user_id,
        email="studio@test.com",
        account_type="production_house",
        full_name="Studio Chief",
        is_verified=False,
    )

    existing_house = ProductionHouse(
        id=uuid.uuid4(),
        user_id=user_id,
        company_name="Existing Studio",
    )

    mock_db = create_mock_session()
    check_existing_result = MagicMock()
    check_existing_result.scalar_one_or_none.return_value = existing_house
    mock_db.execute.return_value = check_existing_result

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return ph_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            payload = {
                "company_name": "Second Studio Attempt",
            }
            res = await client.post(
                "/api/v1/production-houses",
                headers={"Authorization": "Bearer dummy_token"},
                json=payload,
            )
            assert res.status_code == 409
            assert "already exists" in res.json().get("detail", "")
            mock_db.add.assert_not_called()
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_talent_cannot_access_production_house_endpoint_asgi():
    """10. Role Boundary: Talent user calling require_production_house endpoint receives HTTP 403 Forbidden."""
    talent_user = User(
        id=uuid.uuid4(),
        email="talent_boundary@test.com",
        account_type="talent",
        full_name="Talent Boundary",
        is_verified=False,
    )

    mock_db = create_mock_session()

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return talent_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            res = await client.post(
                "/api/v1/production-houses",
                headers={"Authorization": "Bearer dummy_token"},
                json={"company_name": "Unauthorized Studio Attempt"},
            )
            assert res.status_code == 403
            assert "restricted to Production House accounts" in res.json().get("detail", "")
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_production_house_cannot_access_talent_endpoint_asgi():
    """11. Role Boundary: Production House user calling require_talent endpoint receives HTTP 403 Forbidden."""
    ph_user = User(
        id=uuid.uuid4(),
        email="ph_boundary@test.com",
        account_type="production_house",
        full_name="PH Boundary",
        is_verified=False,
    )

    mock_db = create_mock_session()

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return ph_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            res = await client.post(
                "/api/v1/portfolio/",
                headers={"Authorization": "Bearer dummy_token"},
                json={
                    "title": "Unauthorized Headshot",
                    "media_type": "headshot",
                    "media_url": f"public/{ph_user.id}/media/photo.jpg",
                },
            )
            assert res.status_code == 403
            assert "restricted to Talent accounts" in res.json().get("detail", "")
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_established_user_account_type_cannot_be_overwritten_by_jwt_metadata():
    """12. Security & Immutability: An established local user's account_type in PostgreSQL cannot be changed by client JWT metadata."""
    established_user_id = uuid.uuid4()
    established_user = User(
        id=established_user_id,
        email="immutable@test.com",
        account_type="talent",
        full_name="Original Talent",
    )

    # Malicious client sends JWT with self-altered user_metadata claiming account_type: "production_house"
    tampered_jwt_payload = {
        "sub": str(established_user_id),
        "email": "immutable@test.com",
        "user_metadata": {
            "account_type": "production_house",
            "role": "production_house",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = established_user
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=tampered_jwt_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="token")
        resolved_user = await get_current_user(credentials=creds, db=mock_db)

        # The resolved user must retain its established database account_type "talent", NOT the tampered metadata
        assert resolved_user.id == established_user_id
        assert resolved_user.account_type == "talent"
        mock_db.commit.assert_not_called()


@pytest.mark.asyncio
async def test_tampered_metadata_claim_mismatch_defaults_to_talent():
    """13. Initial Provisioning Security: Client tampering before first request (account_type='production_house' but role='talent') defaults safely to 'talent'."""
    user_id = uuid.uuid4()
    tampered_metadata_payload = {
        "sub": str(user_id),
        "email": "attacker@test.com",
        "user_metadata": {
            "account_type": "production_house",  # Injected via client updateUser API
            "role": "talent",                   # Original talent signup role
            "full_name": "Tampering User",
        },
    }

    mock_db = create_mock_session()
    lookup_result = MagicMock()
    lookup_result.scalar_one_or_none.return_value = None  # First time user, not yet provisioned
    mock_db.execute.return_value = lookup_result

    with patch("app.api.dependencies.verify_supabase_jwt", new=AsyncMock(return_value=tampered_metadata_payload)):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="token")
        new_user = await get_current_user(credentials=creds, db=mock_db)

        # Mismatched claim detected: safely defaulted to 'talent'
        assert new_user.id == user_id
        assert new_user.account_type == "talent"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()

