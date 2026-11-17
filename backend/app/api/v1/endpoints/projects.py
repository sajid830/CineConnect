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
from app.models.social import Collaboration
from app.schemas.project import ProjectCreate, ProjectUpdate, ProjectPatch, ProjectResponse
from app.schemas.opportunity import OpportunityResponse
from app.schemas.collaboration import CollaborationResponse

router = APIRouter()


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED, summary="Create Project")
async def create_project(
    data: ProjectCreate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    # Retrieve user's production house
    house_result = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    house = house_result.scalar_one_or_none()
    if not house:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must create a Production House profile before adding projects.",
        )

    project = Project(
        production_house_id=house.id,
        title=data.title,
        description=data.description,
        status=data.status or "development",
        genre=data.genre,
        start_date=data.start_date,
        end_date=data.end_date,
        budget=data.budget,
    )
    db.add(project)
    await db.commit()
    await db.refresh(project)
    return project


@router.get("/my", response_model=List[ProjectResponse], summary="Get Current Production House Projects")
async def get_my_projects(
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    house_result = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    house = house_result.scalar_one_or_none()
    if not house:
        return []

    stmt = select(Project).where(Project.production_house_id == house.id).order_by(Project.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/search", response_model=List[ProjectResponse], summary="Search Projects")
async def search_projects(
    q: Optional[str] = Query(None, description="Search term for title or genre"),
    status_filter: Optional[str] = Query(None, alias="status"),
    genre: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Project)
    conditions = []
    if q:
        conditions.append(or_(Project.title.ilike(f"%{q}%"), Project.description.ilike(f"%{q}%")))
    if status_filter:
        conditions.append(Project.status == status_filter)
    if genre:
        conditions.append(Project.genre.ilike(f"%{genre}%"))

    if conditions:
        stmt = stmt.where(*conditions)

    stmt = stmt.offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{project_id}", response_model=ProjectResponse, summary="Get Project Details")
async def get_project_by_id(project_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


@router.put("/{project_id}", response_model=ProjectResponse, summary="Update Project")
async def update_project(
    project_id: UUID,
    data: ProjectUpdate,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    # Ownership verification
    house_result = await db.execute(select(ProductionHouse).where(ProductionHouse.id == project.production_house_id))
    house = house_result.scalar_one_or_none()
    if not house or house.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this project.")

    project.title = data.title
    project.description = data.description
    project.status = data.status or project.status
    project.genre = data.genre
    project.start_date = data.start_date
    project.end_date = data.end_date
    project.budget = data.budget

    await db.commit()
    await db.refresh(project)
    return project


@router.patch("/{project_id}", response_model=ProjectResponse, summary="Update Selected Project Fields")
async def patch_project(
    project_id: UUID,
    data: ProjectPatch,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    house_result = await db.execute(select(ProductionHouse).where(ProductionHouse.id == project.production_house_id))
    house = house_result.scalar_one_or_none()
    if not house or house.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this project.")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(project, field, value)

    await db.commit()
    await db.refresh(project)
    return project


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete Project")
async def delete_project(
    project_id: UUID,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    house_result = await db.execute(select(ProductionHouse).where(ProductionHouse.id == project.production_house_id))
    house = house_result.scalar_one_or_none()
    if not house or house.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this project.")

    await db.delete(project)
    await db.commit()
    return None


@router.get("", response_model=List[ProjectResponse], summary="List Projects")
async def list_projects(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Project).order_by(Project.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{project_id}/opportunities", response_model=List[OpportunityResponse], summary="Get Project Opportunities")
async def get_project_opportunities(project_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Opportunity).where(Opportunity.project_id == project_id).order_by(Opportunity.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{project_id}/collaborations", response_model=List[CollaborationResponse], summary="Get Project Collaborations")
async def get_project_collaborations(project_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Collaboration).where(Collaboration.project_id == project_id).order_by(Collaboration.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()
