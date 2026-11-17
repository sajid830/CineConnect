import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user, require_talent, require_production_house
from app.models.user import User
from app.models.production_house import ProductionHouse, Project
from app.models.social import Collaboration
from app.schemas.collaboration import (
    CollaborationCreate,
    CollaborationStatusUpdate,
    CollaborationResponse,
)

router = APIRouter()


@router.post("/", response_model=CollaborationResponse, status_code=status.HTTP_201_CREATED)
async def create_collaboration(
    collab_in: CollaborationCreate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Invite a talent user to collaborate on a production project (Production House only)."""
    # 1. Verify production house
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house profile not found")

    # 2. Verify project ownership
    proj_res = await db.execute(
        select(Project).where(
            Project.id == collab_in.project_id,
            Project.production_house_id == ph.id,
        )
    )
    if not proj_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found or does not belong to your production house.",
        )

    # 3. Verify target talent exists
    talent_res = await db.execute(select(User).where(User.id == collab_in.talent_id))
    if not talent_res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Talent user not found")

    # 4. Check existing collaboration for this project & talent
    existing = await db.execute(
        select(Collaboration).where(
            Collaboration.project_id == collab_in.project_id,
            Collaboration.talent_id == collab_in.talent_id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A collaboration invitation or record already exists for this talent on this project.",
        )

    collaboration = Collaboration(
        project_id=collab_in.project_id,
        talent_id=collab_in.talent_id,
        role=collab_in.role,
        status="invited",
    )
    db.add(collaboration)
    await db.commit()
    await db.refresh(collaboration)
    return collaboration


@router.get("/my", response_model=List[CollaborationResponse])
async def list_my_collaborations(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List collaborations associated with the current user (either as talent or as project owner)."""
    # If user is a talent
    if current_user.role == "talent":
        stmt = (
            select(Collaboration)
            .where(Collaboration.talent_id == current_user.id)
            .order_by(Collaboration.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await db.execute(stmt)
        return result.scalars().all()

    # If user is a production house
    ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = ph_res.scalar_one_or_none()
    if ph:
        stmt = (
            select(Collaboration)
            .join(Project, Collaboration.project_id == Project.id)
            .where(Project.production_house_id == ph.id)
            .order_by(Collaboration.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await db.execute(stmt)
        return result.scalars().all()

    return []


@router.get("/{collaboration_id}", response_model=CollaborationResponse)
async def get_collaboration(
    collaboration_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get single collaboration details (Accessible to the talent or project owner)."""
    result = await db.execute(select(Collaboration).where(Collaboration.id == collaboration_id))
    collab = result.scalar_one_or_none()
    if not collab:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collaboration not found")

    if collab.talent_id == current_user.id:
        return collab

    # Check project ownership
    proj_res = await db.execute(select(Project).where(Project.id == collab.project_id))
    project = proj_res.scalar_one_or_none()
    if project:
        ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.id == project.production_house_id))
        ph = ph_res.scalar_one_or_none()
        if ph and ph.user_id == current_user.id:
            return collab

    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not have permission to view this collaboration.")


@router.patch("/{collaboration_id}/accept", response_model=CollaborationResponse)
async def accept_collaboration(
    collaboration_id: uuid.UUID,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Accept a collaboration invitation (Talent only)."""
    result = await db.execute(
        select(Collaboration).where(
            Collaboration.id == collaboration_id,
            Collaboration.talent_id == current_user.id,
        )
    )
    collab = result.scalar_one_or_none()
    if not collab:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Collaboration invitation not found for your account.",
        )

    collab.status = "accepted"
    await db.commit()
    await db.refresh(collab)
    return collab


@router.patch("/{collaboration_id}/reject", response_model=CollaborationResponse)
async def reject_collaboration(
    collaboration_id: uuid.UUID,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Reject a collaboration invitation (Talent only)."""
    result = await db.execute(
        select(Collaboration).where(
            Collaboration.id == collaboration_id,
            Collaboration.talent_id == current_user.id,
        )
    )
    collab = result.scalar_one_or_none()
    if not collab:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Collaboration invitation not found for your account.",
        )

    collab.status = "rejected"
    await db.commit()
    await db.refresh(collab)
    return collab


@router.patch("/{collaboration_id}/status", response_model=CollaborationResponse)
async def update_collaboration_status(
    collaboration_id: uuid.UUID,
    status_in: CollaborationStatusUpdate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Update collaboration lifecycle status (e.g. 'completed', 'cancelled') (Production House owner only)."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Production house not found")

    result = await db.execute(select(Collaboration).where(Collaboration.id == collaboration_id))
    collab = result.scalar_one_or_none()
    if not collab:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collaboration not found")

    proj_res = await db.execute(
        select(Project).where(
            Project.id == collab.project_id,
            Project.production_house_id == ph.id,
        )
    )
    if not proj_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to manage this collaboration.",
        )

    collab.status = status_in.status
    await db.commit()
    await db.refresh(collab)
    return collab


@router.delete("/{collaboration_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_collaboration(
    collaboration_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancel / remove collaboration (Talent or Project Production House owner)."""
    result = await db.execute(select(Collaboration).where(Collaboration.id == collaboration_id))
    collab = result.scalar_one_or_none()
    if not collab:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collaboration not found")

    is_authorized = False
    if collab.talent_id == current_user.id:
        is_authorized = True
    else:
        proj_res = await db.execute(select(Project).where(Project.id == collab.project_id))
        project = proj_res.scalar_one_or_none()
        if project:
            ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.id == project.production_house_id))
            ph = ph_res.scalar_one_or_none()
            if ph and ph.user_id == current_user.id:
                is_authorized = True

    if not is_authorized:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to delete this collaboration.",
        )

    await db.delete(collab)
    await db.commit()
    return None
