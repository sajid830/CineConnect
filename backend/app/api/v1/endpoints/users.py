from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.models.portfolio import PortfolioMedia
from app.models.social import Post, Connection
from app.schemas.user import UserResponse, UserUpdate, UserPatch, UserSearchResponse
from app.schemas.portfolio import PortfolioMediaResponse
from app.schemas.post import PostResponse
from app.schemas.connection import ConnectionResponse

router = APIRouter()


@router.get("/me", response_model=UserResponse, summary="Get Current User Profile")
async def get_my_profile(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse, summary="Update Complete Profile")
async def update_my_profile(
    data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.full_name = data.full_name
    current_user.role = data.role
    current_user.location = data.location
    current_user.bio = data.bio
    current_user.phone = data.phone
    if data.experience_years is not None:
        current_user.experience_years = data.experience_years

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.patch("/me", response_model=UserResponse, summary="Update Selected Profile Fields")
async def patch_my_profile(
    data: UserPatch,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.get("/search", response_model=UserSearchResponse, summary="Search Users")
async def search_users(
    q: Optional[str] = Query(None, description="Search term for name, role, or location"),
    role: Optional[str] = Query(None, description="Filter by craft/role"),
    location: Optional[str] = Query(None, description="Filter by location"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(User)
    conditions = []
    if q:
        conditions.append(
            or_(
                User.full_name.ilike(f"%{q}%"),
                User.role.ilike(f"%{q}%"),
                User.location.ilike(f"%{q}%"),
                User.bio.ilike(f"%{q}%"),
            )
        )
    if role:
        conditions.append(User.role.ilike(f"%{role}%"))
    if location:
        conditions.append(User.location.ilike(f"%{location}%"))

    if conditions:
        query = query.where(*conditions)

    count_stmt = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_stmt)).scalar() or 0

    items_stmt = query.offset(skip).limit(limit)
    users = (await db.execute(items_stmt)).scalars().all()

    return UserSearchResponse(items=list(users), total=total)


@router.get("/{user_id}", response_model=UserResponse, summary="View User Profile")
async def get_user_by_id(user_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.get("", response_model=List[UserResponse], summary="List Users")
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    account_type: Optional[str] = Query(None, description="Filter by talent or production_house"),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User)
    if account_type:
        stmt = stmt.where(User.account_type == account_type)
    stmt = stmt.offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{user_id}/portfolio", response_model=List[PortfolioMediaResponse], summary="View User Portfolio")
async def get_user_portfolio(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(PortfolioMedia).where(PortfolioMedia.user_id == user_id).order_by(PortfolioMedia.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{user_id}/posts", response_model=List[PostResponse], summary="View User Posts")
async def get_user_posts(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Post).where(Post.user_id == user_id).order_by(Post.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{user_id}/connections", response_model=List[ConnectionResponse], summary="View User Connections")
async def get_user_connections(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Connection).where(
        or_(Connection.sender_id == user_id, Connection.receiver_id == user_id),
        Connection.status == "accepted",
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{user_id}/followers", response_model=List[ConnectionResponse], summary="Get Followers")
async def get_user_followers(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Connection).where(Connection.receiver_id == user_id, Connection.status == "accepted")
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{user_id}/following", response_model=List[ConnectionResponse], summary="Get Following List")
async def get_user_following(user_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Connection).where(Connection.sender_id == user_id, Connection.status == "accepted")
    result = await db.execute(stmt)
    return result.scalars().all()
