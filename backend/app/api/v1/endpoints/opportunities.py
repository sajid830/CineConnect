import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user, require_production_house
from app.models.user import User
from app.models.production_house import ProductionHouse, Project
from app.models.opportunity import Opportunity, Application
from app.schemas.opportunity import (
    OpportunityCreate,
    OpportunityUpdate,
    OpportunityPatch,
    OpportunityStatusUpdate,
    OpportunityResponse,
)
from app.schemas.application import ApplicationResponse

router = APIRouter()


@router.post("/", response_model=OpportunityResponse, status_code=status.HTTP_201_CREATED)
async def create_opportunity(
    opp_in: OpportunityCreate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Create a new casting/job opportunity (Production House only)."""
    # 1. Fetch user's production house
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Production house profile not found. Please create your production house profile first.",
        )

    # 2. Verify project exists and belongs to this production house
    proj_res = await db.execute(
        select(Project).where(
            Project.id == opp_in.project_id,
            Project.production_house_id == ph.id,
        )
    )
    project = proj_res.scalar_one_or_none()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found or does not belong to your production house.",
        )

    opp_data = opp_in.model_dump()
    opportunity = Opportunity(
        **opp_data,
        production_house_id=ph.id,
    )
    db.add(opportunity)
    await db.commit()
    await db.refresh(opportunity)
    return opportunity


@router.get("/my", response_model=List[OpportunityResponse])
async def list_my_opportunities(
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """List all opportunities created by the logged-in production house."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        return []

    stmt = select(Opportunity).where(Opportunity.production_house_id == ph.id).order_by(Opportunity.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/search", response_model=List[OpportunityResponse])
async def search_opportunities(
    q: Optional[str] = Query(None, description="Search term for title, role_type, or requirements"),
    location: Optional[str] = Query(None, description="Filter by location"),
    role_type: Optional[str] = Query(None, description="Filter by role type"),
    status: Optional[str] = Query(None, description="Filter by status (open, closed)"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Search opportunities by title, role_type, requirements, or location."""
    stmt = select(Opportunity)
    conditions = []
    if q:
        search_pattern = f"%{q.strip()}%"
        conditions.append(
            or_(
                Opportunity.title.ilike(search_pattern),
                Opportunity.role_type.ilike(search_pattern),
                Opportunity.requirements.ilike(search_pattern),
            )
        )
    if location:
        conditions.append(Opportunity.location.ilike(f"%{location.strip()}%"))
    if role_type:
        conditions.append(Opportunity.role_type.ilike(f"%{role_type.strip()}%"))
    if status:
        conditions.append(Opportunity.status == status)

    if conditions:
        stmt = stmt.where(and_(*conditions))

    stmt = stmt.order_by(Opportunity.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/", response_model=List[OpportunityResponse])
async def list_opportunities(
    role_type: Optional[str] = Query(None, description="Filter by role type"),
    location: Optional[str] = Query(None, description="Filter by location"),
    status: Optional[str] = Query("open", description="Filter by status (default: open)"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """List opportunities with optional filters and pagination."""
    stmt = select(Opportunity)
    conditions = []
    if role_type:
        conditions.append(Opportunity.role_type.ilike(f"%{role_type.strip()}%"))
    if location:
        conditions.append(Opportunity.location.ilike(f"%{location.strip()}%"))
    if status:
        conditions.append(Opportunity.status == status)

    if conditions:
        stmt = stmt.where(and_(*conditions))

    stmt = stmt.order_by(Opportunity.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{opportunity_id}", response_model=OpportunityResponse)
async def get_opportunity(
    opportunity_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get single opportunity by ID."""
    result = await db.execute(select(Opportunity).where(Opportunity.id == opportunity_id))
    opp = result.scalar_one_or_none()
    if not opp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Opportunity not found")
    return opp


@router.put("/{opportunity_id}", response_model=OpportunityResponse)
async def update_opportunity(
    opportunity_id: uuid.UUID,
    opp_in: OpportunityUpdate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Update complete opportunity (Production House owner only)."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")

    opp_res = await db.execute(
        select(Opportunity).where(
            Opportunity.id == opportunity_id,
            Opportunity.production_house_id == ph.id,
        )
    )
    opp = opp_res.scalar_one_or_none()
    if not opp:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found or you do not have permission to edit it.",
        )

    for field, value in opp_in.model_dump().items():
        setattr(opp, field, value)

    await db.commit()
    await db.refresh(opp)
    return opp


@router.patch("/{opportunity_id}", response_model=OpportunityResponse)
async def patch_opportunity(
    opportunity_id: uuid.UUID,
    opp_in: OpportunityPatch,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Partially update opportunity (Production House owner only)."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")

    opp_res = await db.execute(
        select(Opportunity).where(
            Opportunity.id == opportunity_id,
            Opportunity.production_house_id == ph.id,
        )
    )
    opp = opp_res.scalar_one_or_none()
    if not opp:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found or you do not have permission to edit it.",
        )

    for field, value in opp_in.model_dump(exclude_unset=True).items():
        setattr(opp, field, value)

    await db.commit()
    await db.refresh(opp)
    return opp


@router.delete("/{opportunity_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_opportunity(
    opportunity_id: uuid.UUID,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Delete opportunity (Production House owner only)."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")

    opp_res = await db.execute(
        select(Opportunity).where(
            Opportunity.id == opportunity_id,
            Opportunity.production_house_id == ph.id,
        )
    )
    opp = opp_res.scalar_one_or_none()
    if not opp:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found or you do not have permission to delete it.",
        )

    await db.delete(opp)
    await db.commit()
    return None


@router.get("/{opportunity_id}/applications", response_model=List[ApplicationResponse])
async def list_opportunity_applications(
    opportunity_id: uuid.UUID,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """List all candidate applications submitted for this opportunity (Owner only)."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")

    opp_res = await db.execute(
        select(Opportunity).where(
            Opportunity.id == opportunity_id,
            Opportunity.production_house_id == ph.id,
        )
    )
    opp = opp_res.scalar_one_or_none()
    if not opp:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found or you do not have permission to view its applications.",
        )

    stmt = select(Application).where(Application.opportunity_id == opportunity_id).order_by(Application.created_at.desc())
    app_result = await db.execute(stmt)
    return app_result.scalars().all()


@router.patch("/{opportunity_id}/status", response_model=OpportunityResponse)
async def update_opportunity_status(
    opportunity_id: uuid.UUID,
    status_in: OpportunityStatusUpdate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Update opportunity status (e.g., 'open', 'closed', 'draft') (Owner only)."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")

    opp_res = await db.execute(
        select(Opportunity).where(
            Opportunity.id == opportunity_id,
            Opportunity.production_house_id == ph.id,
        )
    )
    opp = opp_res.scalar_one_or_none()
    if not opp:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found or you do not have permission to modify its status.",
        )

    opp.status = status_in.status
    await db.commit()
    await db.refresh(opp)
    return opp
