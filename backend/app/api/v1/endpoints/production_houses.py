from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, require_production_house
from app.db.session import get_db
from app.models.user import User
from app.models.production_house import ProductionHouse, Project
from app.models.opportunity import Opportunity
from app.schemas.production_house import (
    ProductionHouseCreate,
    ProductionHouseUpdate,
    ProductionHouseResponse,
)
from app.schemas.project import ProjectResponse
from app.schemas.opportunity import OpportunityResponse
from app.services.storage import (
    acquire_public_media_advisory_locks,
    validate_public_media_ownership,
    cleanup_unreferenced_public_media,
)

router = APIRouter()


@router.post("", response_model=ProductionHouseResponse, status_code=status.HTTP_201_CREATED, summary="Create Production House Profile")
async def create_production_house(
    data: ProductionHouseCreate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    # Check if user already has a production house
    existing = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Production house profile already exists for this account.",
        )

    # Protect logo attachment if provided
    if data.logo_url:
        await acquire_public_media_advisory_locks(db, [data.logo_url])
        validate_public_media_ownership(
            url_or_key=data.logo_url,
            user_id=current_user.id,
            field_name="logo_url",
            verify_exists=True,
        )

    house = ProductionHouse(
        user_id=current_user.id,
        company_name=data.company_name,
        description=data.description,
        location=data.location,
        specialization=data.specialization,
        website=data.website,
        logo_url=data.logo_url,
    )
    db.add(house)
    await db.commit()
    await db.refresh(house)
    house.user = current_user
    return house


@router.get("/me", response_model=ProductionHouseResponse, summary="Get Current Production House Profile")
async def get_my_production_house(
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ProductionHouse).where(ProductionHouse.user_id == current_user.id)
    result = await db.execute(stmt)
    house = result.scalar_one_or_none()
    if not house:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house profile not created yet.")
    house.user = current_user
    return house


@router.put("/me", response_model=ProductionHouseResponse, summary="Update Current Production House Profile")
async def update_my_production_house(
    data: ProductionHouseUpdate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ProductionHouse).where(ProductionHouse.user_id == current_user.id)
    result = await db.execute(stmt)
    house = result.scalar_one_or_none()
    if not house:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house profile not found.")

    old_logo_url = house.logo_url

    if data.logo_url and data.logo_url != old_logo_url:
        await acquire_public_media_advisory_locks(db, [data.logo_url])
        validate_public_media_ownership(
            url_or_key=data.logo_url,
            user_id=current_user.id,
            field_name="logo_url",
            verify_exists=True,
        )

    house.company_name = data.company_name
    house.description = data.description
    house.location = data.location
    house.specialization = data.specialization
    house.website = data.website
    house.logo_url = data.logo_url

    await db.commit()
    await db.refresh(house)
    house.user = current_user

    if old_logo_url and old_logo_url != data.logo_url:
        await cleanup_unreferenced_public_media(db=db, urls_to_check=[old_logo_url])

    return house


@router.get("/search", response_model=List[ProductionHouseResponse], summary="Search Production Houses")
async def search_production_houses(
    q: Optional[str] = Query(None, description="Search query for company name or specialization"),
    location: Optional[str] = Query(None, description="Filter by location"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ProductionHouse)
    conditions = []
    if q:
        conditions.append(
            or_(
                ProductionHouse.company_name.ilike(f"%{q}%"),
                ProductionHouse.specialization.ilike(f"%{q}%"),
                ProductionHouse.description.ilike(f"%{q}%"),
            )
        )
    if location:
        conditions.append(ProductionHouse.location.ilike(f"%{location}%"))

    if conditions:
        stmt = stmt.where(*conditions)

    stmt = stmt.offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{house_id}", response_model=ProductionHouseResponse, summary="View Production House Details")
async def get_production_house_by_id(house_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ProductionHouse).where(ProductionHouse.id == house_id))
    house = result.scalar_one_or_none()
    if not house:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")
    return house


@router.get("", response_model=List[ProductionHouseResponse], summary="List Production Houses")
async def list_production_houses(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ProductionHouse).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{house_id}/projects", response_model=List[ProjectResponse], summary="Get Production House Projects")
async def get_production_house_projects(house_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Project).where(Project.production_house_id == house_id).order_by(Project.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{house_id}/opportunities", response_model=List[OpportunityResponse], summary="Get Production House Opportunities")
async def get_production_house_opportunities(house_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Opportunity).where(Opportunity.production_house_id == house_id).order_by(Opportunity.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()
