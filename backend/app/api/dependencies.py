from uuid import UUID
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import logger
from app.core.security import verify_supabase_jwt
from app.db.session import get_db
from app.models.user import User

security_scheme = HTTPBearer(
    scheme_name="SupabaseBearerAuth",
    description="Pass Supabase Auth JWT Access Token: Bearer <token>",
    auto_error=True,
)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Extracts, verifies, and synchronizes the authenticated Supabase user."""
    token = credentials.credentials
    payload = verify_supabase_jwt(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    sub = payload.get("sub")
    try:
        user_uuid = UUID(str(sub))
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID format in token claims.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Query local users table
    stmt = select(User).where(User.id == user_uuid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    # Automatic synchronization with Supabase Auth identity
    if user is None:
        email = payload.get("email", f"user_{str(user_uuid)[:8]}@cineconnect.com")
        metadata = payload.get("user_metadata", {})
        account_type = metadata.get("account_type", "talent")
        full_name = metadata.get("full_name") or metadata.get("name")

        # Check if record with this email already exists
        email_stmt = select(User).where(User.email == email)
        email_result = await db.execute(email_stmt)
        existing_user = email_result.scalar_one_or_none()

        if existing_user is not None:
            user = existing_user
        else:
            logger.info(f"Synchronizing new Supabase Auth user: {user_uuid} ({email})")
            user = User(
                id=user_uuid,
                email=email,
                account_type=account_type if account_type in ("talent", "production_house") else "talent",
                full_name=full_name,
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)

    return user


async def require_talent(
    current_user: User = Depends(get_current_user),
) -> User:
    """Restricts access to authenticated Talent accounts only."""
    if current_user.account_type != "talent":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: This action is restricted to Talent accounts.",
        )
    return current_user


async def require_production_house(
    current_user: User = Depends(get_current_user),
) -> User:
    """Restricts access to authenticated Production House accounts only."""
    if current_user.account_type != "production_house":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: This action is restricted to Production House accounts.",
        )
    return current_user
