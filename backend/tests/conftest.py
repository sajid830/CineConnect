from typing import AsyncGenerator
from uuid import UUID
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from app.main import app
from app.core.config import settings
from app.core.security import create_test_token
from app.db.session import get_db

# Asynchronous PostgreSQL test engine connected to cineconnect_test_db
test_engine = create_async_engine(
    settings.async_test_database_url,
    echo=False,
    future=True,
    poolclass=NullPool,
)

# Canonical Test Persona UUIDs
TALENT_USER_ID = UUID("11111111-1111-1111-1111-111111111111")
PH_USER_ID = UUID("22222222-2222-2222-2222-222222222222")
ADMIN_USER_ID = UUID("33333333-3333-3333-3333-333333333333")
PH2_USER_ID = UUID("44444444-4444-4444-4444-444444444444")
TALENT2_USER_ID = UUID("55555555-5555-5555-5555-555555555555")


@pytest_asyncio.fixture(scope="session", loop_scope="session", autouse=True)
async def cleanup_test_engine():
    """Cleanly disposes the test engine on session teardown."""
    yield
    await test_engine.dispose()


@pytest_asyncio.fixture(scope="function")
async def test_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provides an isolated database session wrapped in an outer transaction.
    
    Any committed changes made during tests are contained in a savepoint
    and rolled back completely on teardown, leaving cineconnect_test_db pristine.
    """
    async with test_engine.connect() as connection:
        transaction = await connection.begin()
        session = AsyncSession(
            bind=connection,
            expire_on_commit=False,
            autocommit=False,
            autoflush=False,
            join_transaction_mode="create_savepoint",
        )
        try:
            yield session
        finally:
            await session.close()
            await transaction.rollback()


@pytest_asyncio.fixture(scope="function")
async def async_client(test_db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Provides an asynchronous HTTP test client with overridden database dependency."""
    async def override_get_db():
        yield test_db_session

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        yield client

    app.dependency_overrides.clear()


# ==============================================================================
# Authentication Test Fixtures
# ==============================================================================

@pytest.fixture
def talent_user_id() -> UUID:
    """Returns Canonical Talent User UUID."""
    return TALENT_USER_ID


@pytest.fixture
def talent_token() -> str:
    """Generates a valid test Supabase JWT for the Talent persona."""
    return create_test_token(
        user_id=TALENT_USER_ID,
        email="talent@testcineconnect.com",
        account_type="talent",
        extra_claims={
            "user_metadata": {
                "account_type": "talent",
                "role": "talent",
                "full_name": "Test Talent User",
            }
        },
    )


@pytest.fixture
def talent_headers(talent_token: str) -> dict:
    """Returns HTTP Authorization headers for Talent persona."""
    return {"Authorization": f"Bearer {talent_token}"}


@pytest.fixture
def ph_user_id() -> UUID:
    """Returns Canonical Production House User UUID."""
    return PH_USER_ID


@pytest.fixture
def ph_token() -> str:
    """Generates a valid test Supabase JWT for the Production House persona."""
    return create_test_token(
        user_id=PH_USER_ID,
        email="producer@testcineconnect.com",
        account_type="production_house",
        extra_claims={
            "user_metadata": {
                "account_type": "production_house",
                "role": "production_house",
                "full_name": "Test Producer User",
            }
        },
    )


@pytest.fixture
def ph_headers(ph_token: str) -> dict:
    """Returns HTTP Authorization headers for Production House persona."""
    return {"Authorization": f"Bearer {ph_token}"}


@pytest.fixture
def ph2_user_id() -> UUID:
    """Returns Canonical Secondary Production House User UUID."""
    return PH2_USER_ID


@pytest.fixture
def ph2_token() -> str:
    """Generates a valid test Supabase JWT for the Secondary Production House persona."""
    return create_test_token(
        user_id=PH2_USER_ID,
        email="producer2@testcineconnect.com",
        account_type="production_house",
        extra_claims={
            "user_metadata": {
                "account_type": "production_house",
                "role": "production_house",
                "full_name": "Second Producer User",
            }
        },
    )


@pytest.fixture
def ph2_headers(ph2_token: str) -> dict:
    """Returns HTTP Authorization headers for Secondary Production House persona."""
    return {"Authorization": f"Bearer {ph2_token}"}


@pytest.fixture
def talent2_user_id() -> UUID:
    """Returns Canonical Secondary Talent User UUID."""
    return TALENT2_USER_ID


@pytest.fixture
def talent2_token() -> str:
    """Generates a valid test Supabase JWT for the Secondary Talent persona."""
    return create_test_token(
        user_id=TALENT2_USER_ID,
        email="talent2@testcineconnect.com",
        account_type="talent",
        extra_claims={
            "user_metadata": {
                "account_type": "talent",
                "role": "talent",
                "full_name": "Second Talent User",
            }
        },
    )


@pytest.fixture
def talent2_headers(talent2_token: str) -> dict:
    """Returns HTTP Authorization headers for Secondary Talent persona."""
    return {"Authorization": f"Bearer {talent2_token}"}


@pytest.fixture
def expired_token() -> str:
    """Generates an expired test Supabase JWT."""
    return create_test_token(
        user_id=TALENT_USER_ID,
        email="expired@testcineconnect.com",
        account_type="talent",
        expires_in_seconds=-3600,
    )


@pytest.fixture
def expired_headers(expired_token: str) -> dict:
    """Returns HTTP Authorization headers with an expired token."""
    return {"Authorization": f"Bearer {expired_token}"}


@pytest.fixture
def invalid_headers() -> dict:
    """Returns HTTP Authorization headers with a malformed token."""
    return {"Authorization": "Bearer invalid.malformed.jwt.token"}
