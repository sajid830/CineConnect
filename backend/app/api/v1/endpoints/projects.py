from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, require_production_house
from app.db.session import get_db
from app.models.user import User
from app.models.production_house import ProductionHouse, Project
from app.models.opportunity import Opportunity, Application
from app.models.social import Collaboration
from app.schemas.project import ProjectCreate, ProjectUpdate, ProjectPatch, ProjectResponse
from app.schemas.opportunity import OpportunityResponse
from app.schemas.collaboration import CollaborationResponse
from app.schemas.application import ApplicationResponse
from app.api.v1.endpoints.collaborations import to_ph_collaboration_response
from app.api.v1.endpoints.applications import to_ph_application_response

router = APIRouter()


def _enrich_project_response(project: Project, apps_count: int = 0) -> ProjectResponse:
    ph_name = None
    ph_logo = None
    if "production_house" in project.__dict__ and project.production_house:
        ph_name = project.production_house.company_name
        ph_logo = project.production_house.logo_url
    return ProjectResponse(
        id=project.id,
        production_house_id=project.production_house_id,
        title=project.title,
        description=project.description,
        status=project.status,
        project_type=project.project_type or project.genre,
        genre=project.genre,
        start_date=project.start_date,
        end_date=project.end_date,
        budget=project.budget,
        production_house_name=ph_name,
        production_house_logo=ph_logo,
        applications_count=apps_count,
        created_at=project.created_at,
        updated_at=project.updated_at,
    )


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
        project_type=data.project_type or data.genre,
        genre=data.genre,
        start_date=data.start_date,
        end_date=data.end_date,
        budget=data.budget,
    )
    db.add(project)
    await db.commit()
    await db.refresh(project)
    project.production_house = house

    # Important: Projects must not automatically appear in the Jobs section.
    # Individual crew requirements are created explicitly under Jobs.
    return _enrich_project_response(project, apps_count=0)


@router.get("/my", response_model=List[ProjectResponse], summary="Get Current Production House Projects")
async def get_my_projects(
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    house_result = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    house = house_result.scalar_one_or_none()
    if not house:
        return []

    stmt = (
        select(Project)
        .where(Project.production_house_id == house.id)
        .options(selectinload(Project.production_house))
        .order_by(Project.created_at.desc())
    )
    result = await db.execute(stmt)
    projects = result.scalars().all()

    # Get application counts per project
    counts_res = await db.execute(
        select(Application.project_id, func.count(Application.id))
        .where(Application.project_id.in_([p.id for p in projects]))
        .group_by(Application.project_id)
    )
    counts_map = dict(counts_res.all()) if projects else {}

    return [_enrich_project_response(p, counts_map.get(p.id, 0)) for p in projects]


@router.get("/search", response_model=List[ProjectResponse], summary="Search Projects")
async def search_projects(
    q: Optional[str] = Query(None, description="Search term for title or genre"),
    status_filter: Optional[str] = Query(None, alias="status"),
    genre: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Project).options(selectinload(Project.production_house))
    conditions = []
    if q:
        conditions.append(or_(Project.title.ilike(f"%{q}%"), Project.description.ilike(f"%{q}%")))
    if status_filter:
        conditions.append(Project.status == status_filter)
    if genre:
        conditions.append(or_(Project.genre.ilike(f"%{genre}%"), Project.project_type.ilike(f"%{genre}%")))

    if conditions:
        stmt = stmt.where(*conditions)

    stmt = stmt.order_by(Project.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    projects = result.scalars().all()
    return [_enrich_project_response(p) for p in projects]


@router.get("/{project_id}", response_model=ProjectResponse, summary="Get Project Details")
async def get_project_by_id(project_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Project)
        .where(Project.id == project_id)
        .options(selectinload(Project.production_house))
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    count_res = await db.execute(
        select(func.count(Application.id)).where(Application.project_id == project.id)
    )
    apps_count = count_res.scalar_one() or 0
    return _enrich_project_response(project, apps_count)


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
    project.project_type = data.project_type or data.genre
    project.genre = data.genre
    project.start_date = data.start_date
    project.end_date = data.end_date
    project.budget = data.budget

    await db.commit()
    await db.refresh(project)
    project.production_house = house
    return _enrich_project_response(project)


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
    project.production_house = house
    return _enrich_project_response(project)


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
    stmt = (
        select(Project)
        .options(selectinload(Project.production_house))
        .order_by(Project.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    projects = result.scalars().all()
    return [_enrich_project_response(p) for p in projects]


@router.get("/{project_id}/applications", response_model=List[ApplicationResponse], summary="Get Project Applicants (Owner Only)")
async def get_project_applications(
    project_id: UUID,
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    # Verify project exists and belongs to current production house
    house_res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    house = house_res.scalar_one_or_none()
    if not house:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Production house profile required.")

    proj_res = await db.execute(select(Project).where(Project.id == project_id, Project.production_house_id == house.id))
    project = proj_res.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found or not owned by you.")

    stmt = (
        select(Application)
        .where(Application.project_id == project_id)
        .options(selectinload(Application.talent), selectinload(Application.project))
        .order_by(Application.created_at.desc())
    )
    result = await db.execute(stmt)
    apps = result.scalars().all()
    return [to_ph_application_response(a) for a in apps]


@router.get("/{project_id}/opportunities", response_model=List[OpportunityResponse], summary="Get Project Opportunities")
async def get_project_opportunities(project_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Opportunity).where(Opportunity.project_id == project_id).order_by(Opportunity.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{project_id}/collaborations", response_model=List[CollaborationResponse], summary="Get Project Collaborations")
async def get_project_collaborations(project_id: UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Collaboration).where(Collaboration.project_id == project_id).order_by(Collaboration.created_at.desc())
    result = await db.execute(stmt)
    collabs = result.scalars().all()
    return [to_ph_collaboration_response(c) for c in collabs]
