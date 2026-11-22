from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User, FilmCredit
from app.models.portfolio import PortfolioMedia
from app.models.social import Post, Connection
from app.schemas.user import UserResponse, UserUpdate, UserPatch, UserSearchResponse
from app.schemas.film_credit import (
    FilmCreditCreate,
    FilmCreditUpdate,
    FilmCreditResponse,
)
from app.schemas.portfolio import PortfolioMediaResponse
from app.api.v1.endpoints.portfolio import format_portfolio_response
from app.schemas.post import PostResponse
from app.schemas.connection import ConnectionResponse

router = APIRouter()


async def enrich_user_response(user: User, db: AsyncSession) -> UserResponse:
    conn_count_stmt = select(func.count(Connection.id)).where(
        or_(Connection.follower_id == user.id, Connection.following_id == user.id),
        Connection.status == "accepted",
        Connection.deleted_at.is_(None),
    )
    conn_count = (await db.execute(conn_count_stmt)).scalar() or 0

    film_credits_stmt = (
        select(FilmCredit)
        .where(FilmCredit.user_id == user.id)
        .order_by(FilmCredit.release_year.desc(), FilmCredit.created_at.desc())
    )
    film_credits = (await db.execute(film_credits_stmt)).scalars().all()
    filmography = [FilmCreditResponse.model_validate(c) for c in film_credits]

    user_resp = UserResponse.model_validate(user)
    user_resp.connections_count = conn_count
    user_resp.endorsements_count = None
    user_resp.filmography = filmography
    return user_resp


@router.get("/me", response_model=UserResponse, summary="Get Current User Profile")
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await enrich_user_response(current_user, db)


@router.put("/me", response_model=UserResponse, summary="Update Complete Profile")
async def update_my_profile(
    data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)

    await db.commit()
    await db.refresh(current_user)
    return await enrich_user_response(current_user, db)


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
    return await enrich_user_response(current_user, db)


@router.get("/me/filmography", response_model=List[FilmCreditResponse], summary="Get Current User Filmography")
async def get_my_filmography(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(FilmCredit)
        .where(FilmCredit.user_id == current_user.id)
        .order_by(FilmCredit.release_year.desc(), FilmCredit.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/me/filmography", response_model=FilmCreditResponse, status_code=status.HTTP_201_CREATED, summary="Add Film Credit")
async def create_film_credit(
    data: FilmCreditCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    credit = FilmCredit(
        user_id=current_user.id,
        film_title=data.film_title,
        release_year=data.release_year,
        craft_role=data.craft_role,
        director_name=data.director_name,
        studio_banner=data.studio_banner,
        verified_by_guild=False,
        guild_verification_hash=None,
    )
    db.add(credit)
    await db.commit()
    await db.refresh(credit)
    return credit


@router.put("/me/filmography/{credit_id}", response_model=FilmCreditResponse, summary="Update Film Credit")
async def update_film_credit(
    credit_id: UUID,
    data: FilmCreditUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(FilmCredit).where(FilmCredit.id == credit_id, FilmCredit.user_id == current_user.id)
    result = await db.execute(stmt)
    credit = result.scalar_one_or_none()
    if not credit:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Film credit not found")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(credit, field, value)

    await db.commit()
    await db.refresh(credit)
    return credit


@router.delete("/me/filmography/{credit_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete Film Credit")
async def delete_film_credit(
    credit_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(FilmCredit).where(FilmCredit.id == credit_id, FilmCredit.user_id == current_user.id)
    result = await db.execute(stmt)
    credit = result.scalar_one_or_none()
    if not credit:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Film credit not found")

    await db.delete(credit)
    await db.commit()
    return None


@router.get("/search", response_model=UserSearchResponse, summary="Search Users")
async def search_users(
    q: Optional[str] = Query(None, description="Search term for name, role, or location"),
    role: Optional[str] = Query(None, description="Filter by craft/role"),
    location: Optional[str] = Query(None, description="Filter by location"),
    account_type: Optional[str] = Query(None, description="Filter by account type: talent or production_house"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(User)
    conditions = []
    if account_type:
        conditions.append(User.account_type == account_type)
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
    return await enrich_user_response(user, db)


@router.get("/{user_id}/filmography", response_model=List[FilmCreditResponse], summary="Get User Filmography")
async def get_user_filmography(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(FilmCredit)
        .where(FilmCredit.user_id == user_id)
        .order_by(FilmCredit.release_year.desc(), FilmCredit.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


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
    return [format_portfolio_response(m) for m in result.scalars().all()]


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
