from uuid import UUID
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
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
    """Extracts, verifies, and synchronizes the authenticated Supabase user.

    Enforces that Supabase JWT sub UUID is the sole authority for identity.
    If the UUID exists in PostgreSQL, authenticates that exact user directly.
    If the UUID does not exist, provisions a new local user with that exact UUID.
    If the email already belongs to a different UUID, raises HTTP 409 Conflict.
    Handles concurrent first-time provisioning safely via IntegrityError recovery.
    """
    token = credentials.credentials
    payload = await verify_supabase_jwt(token)

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

    # 1. Look up users exclusively by User.id == user_uuid
    stmt = select(User).where(User.id == user_uuid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    # 2. If the UUID already exists, return that user directly
    if user is not None:
        return user

    # 3. UUID does not exist: Provision a new local user using that exact UUID
    raw_email = payload.get("email")
    if raw_email and isinstance(raw_email, str) and raw_email.strip():
        email = raw_email.strip()
    else:
        # Full UUID hexadecimal representation (32 hex characters) prevents collisions
        email = f"user_{user_uuid.hex}@cineconnect.com"

    # Before provisioning, check whether the email is already owned by another UUID
    email_stmt = select(User).where(User.email == email)
    email_result = await db.execute(email_stmt)
    existing_user_by_email = email_result.scalar_one_or_none()
    if existing_user_by_email is not None:
        if existing_user_by_email.id == user_uuid:
            # Created concurrently by another request for this exact user
            return existing_user_by_email

        logger.warning(
            "Rejecting JIT provisioning for Supabase user %s: email '%s' already belongs to local user %s",
            user_uuid,
            email,
            existing_user_by_email.id,
        )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email address already exists.",
        )

    metadata = payload.get("user_metadata", {}) or {}
    raw_account_type = metadata.get("account_type")

    # Safe backward compatibility: check legacy 'role' claim if account_type is omitted
    if not raw_account_type or not isinstance(raw_account_type, str) or not raw_account_type.strip():
        legacy_role = metadata.get("role")
        if isinstance(legacy_role, str) and legacy_role.strip().lower() in (
            "production",
            "production_house",
            "production_hub",
        ):
            raw_account_type = "production_house"
        else:
            raw_account_type = "talent"

    normalized_type = raw_account_type.strip().lower()

    # Canonical validation: accept talent and production_house (and normalize legacy 'production')
    if normalized_type in ("production_house", "production", "production_hub"):
        # Validate against cross-claim inconsistency: if legacy 'role' exists and conflicts with production_house (e.g. role='talent' or role='user'),
        # this indicates tampering. Safely fallback to talent.
        legacy_role = metadata.get("role")
        if isinstance(legacy_role, str) and legacy_role.strip().lower() in ("talent", "user"):
            logger.warning(
                "Suspicious claim mismatch during JIT provisioning for user %s: account_type='%s' but role='%s'. Defaulting to talent.",
                user_uuid,
                raw_account_type,
                legacy_role,
            )
            account_type = "talent"
        else:
            account_type = "production_house"
    elif normalized_type in ("talent", "user"):
        account_type = "talent"
    else:
        # Untrusted claims (e.g. self-assigned 'admin') or unrecognized values safely default to 'talent'
        account_type = "talent"
    full_name = metadata.get("full_name") or metadata.get("name")

    logger.info("Synchronizing new Supabase Auth user: %s (%s)", user_uuid, email)
    new_user = User(
        id=user_uuid,
        email=email,
        account_type=account_type,
        full_name=full_name,
    )
    db.add(new_user)

    try:
        await db.commit()
        await db.refresh(new_user)
        return new_user
    except IntegrityError as exc:
        # Roll back the failed transaction
        await db.rollback()

        # Re-query the database using the exact Supabase UUID
        retry_stmt = select(User).where(User.id == user_uuid)
        retry_result = await db.execute(retry_stmt)
        concurrent_user = retry_result.scalar_one_or_none()

        # If that UUID now exists, return the existing user created by the concurrent request
        if concurrent_user is not None:
            return concurrent_user

        # If no user exists for that UUID, check whether the email belongs to a different UUID
        conflict_stmt = select(User).where(User.email == email)
        conflict_result = await db.execute(conflict_stmt)
        conflict_user = conflict_result.scalar_one_or_none()

        # Return HTTP 409 only if that conflict is confirmed
        if conflict_user is not None and conflict_user.id != user_uuid:
            logger.warning(
                "IntegrityError confirmed email conflict for user %s: email '%s' owned by user %s",
                user_uuid,
                email,
                conflict_user.id,
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email address already exists.",
            )

        # If neither condition explains the error, re-raise the original exception
        raise exc


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
