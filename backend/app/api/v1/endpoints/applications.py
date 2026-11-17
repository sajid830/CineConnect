import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user, require_talent, require_production_house
from app.models.user import User
from app.models.production_house import ProductionHouse
from app.models.opportunity import Opportunity, Application
from app.schemas.application import (
    ApplicationCreate,
    ApplicationUpdate,
    ApplicationPatch,
    ApplicationStatusUpdate,
    ApplicationResponse,
)

router = APIRouter()


@router.post("/", response_model=ApplicationResponse, status_code=status.HTTP_201_CREATED)
async def submit_application(
    app_in: ApplicationCreate,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Submit an application to an open opportunity (Talent only)."""
    # 1. Verify opportunity exists and is open
    opp_res = await db.execute(select(Opportunity).where(Opportunity.id == app_in.opportunity_id))
    opp = opp_res.scalar_one_or_none()
    if not opp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Opportunity not found")
    if opp.status != "open":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"This opportunity is currently {opp.status} and is not accepting applications.",
        )

    # 2. Check for duplicate application
    existing_res = await db.execute(
        select(Application).where(
            Application.opportunity_id == app_in.opportunity_id,
            Application.talent_id == current_user.id,
        )
    )
    if existing_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You have already submitted an application for this opportunity.",
        )

    application = Application(
        opportunity_id=app_in.opportunity_id,
        talent_id=current_user.id,
        cover_letter=app_in.cover_letter,
        resume_url=app_in.resume_url,
        reel_url=app_in.reel_url,
        status="submitted",
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)
    return application


@router.get("/my", response_model=List[ApplicationResponse])
async def list_my_applications(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by application status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """List applications submitted by the logged-in talent user."""
    stmt = select(Application).where(Application.talent_id == current_user.id)
    if status_filter:
        stmt = stmt.where(Application.status == status_filter)
    stmt = stmt.order_by(Application.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/", response_model=List[ApplicationResponse])
async def list_applications_for_production_house(
    opportunity_id: Optional[uuid.UUID] = Query(None, description="Filter by opportunity ID"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """List all candidate applications received by the logged-in production house."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        return []

    # Join Application with Opportunity to filter only this PH's opportunities
    stmt = (
        select(Application)
        .join(Opportunity, Application.opportunity_id == Opportunity.id)
        .where(Opportunity.production_house_id == ph.id)
    )
    if opportunity_id:
        stmt = stmt.where(Application.opportunity_id == opportunity_id)
    if status_filter:
        stmt = stmt.where(Application.status == status_filter)

    stmt = stmt.order_by(Application.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{application_id}", response_model=ApplicationResponse)
async def get_application(
    application_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get single application details (Accessible to the applicant or the opportunity's production house)."""
    result = await db.execute(select(Application).where(Application.id == application_id))
    app_record = result.scalar_one_or_none()
    if not app_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found")

    # If user is the applicant
    if app_record.talent_id == current_user.id:
        return app_record

    # If user is production house owner of the opportunity
    opp_res = await db.execute(select(Opportunity).where(Opportunity.id == app_record.opportunity_id))
    opp = opp_res.scalar_one_or_none()
    if opp:
        ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.id == opp.production_house_id))
        ph = ph_res.scalar_one_or_none()
        if ph and ph.user_id == current_user.id:
            return app_record

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to view this application.",
    )


@router.patch("/{application_id}", response_model=ApplicationResponse)
async def update_application(
    application_id: uuid.UUID,
    app_in: ApplicationPatch,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Update submitted application fields (e.g. cover letter, reel URL) (Talent owner only)."""
    result = await db.execute(
        select(Application).where(
            Application.id == application_id,
            Application.talent_id == current_user.id,
        )
    )
    app_record = result.scalar_one_or_none()
    if not app_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Application not found or you do not have permission to edit it.",
        )

    for field, value in app_in.model_dump(exclude_unset=True).items():
        setattr(app_record, field, value)

    await db.commit()
    await db.refresh(app_record)
    return app_record


@router.delete("/{application_id}", status_code=status.HTTP_204_NO_CONTENT)
async def withdraw_application(
    application_id: uuid.UUID,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Withdraw an application (Talent owner only)."""
    result = await db.execute(
        select(Application).where(
            Application.id == application_id,
            Application.talent_id == current_user.id,
        )
    )
    app_record = result.scalar_one_or_none()
    if not app_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Application not found or you do not have permission to withdraw it.",
        )

    await db.delete(app_record)
    await db.commit()
    return None


@router.patch("/{application_id}/status", response_model=ApplicationResponse)
async def update_application_status(
    application_id: uuid.UUID,
    status_in: ApplicationStatusUpdate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Update application status (e.g. 'under_review', 'shortlisted', 'rejected', 'accepted') (PH owner only)."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")

    result = await db.execute(select(Application).where(Application.id == application_id))
    app_record = result.scalar_one_or_none()
    if not app_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found")

    # Check that this application belongs to an opportunity owned by this PH
    opp_res = await db.execute(select(Opportunity).where(Opportunity.id == app_record.opportunity_id))
    opp = opp_res.scalar_one_or_none()
    if not opp or opp.production_house_id != ph.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to change status for this application.",
        )

    app_record.status = status_in.status
    await db.commit()
    await db.refresh(app_record)
    return app_record
