import logging
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user, require_talent, require_production_house
from app.models.user import User
from app.models.production_house import ProductionHouse, Project
from app.models.opportunity import Opportunity, Application
from app.schemas.application import (
    ApplicationCreate,
    ApplicationUpdate,
    ApplicationPatch,
    ApplicationStatusUpdate,
    ApplicationResponse,
    ApplicationDownloadUrlResponse,
)
from app.services.storage import (
    extract_file_key,
    get_application_file_download_url,
    validate_talent_media_ownership,
    cleanup_unreferenced_application_media,
    count_application_media_references,
    acquire_media_advisory_locks,
)

logger = logging.getLogger("cineconnect.applications")

router = APIRouter()


def to_authorized_application_response(
    app: Application,
    is_ph: bool = False,
) -> ApplicationResponse:
    """Serializes Application to ApplicationResponse, dynamically generating temporary
    presigned download URLs for private resume_url and reel_url.
    Translates canonical 'submitted' status to PH 'received' status when is_ph=True.
    """
    res = ApplicationResponse.model_validate(app)
    if is_ph and res.status == "submitted":
        res.status = "received"

    if app.project_id:
        res.target_type = "project"
        if "project" in app.__dict__ and app.project:
            res.project_title = app.project.title
    elif app.opportunity_id:
        res.target_type = "job"
        if "opportunity" in app.__dict__ and app.opportunity:
            res.opportunity_title = app.opportunity.title

    # Dynamically sign private storage URLs for authorized user
    if res.resume_url:
        res.resume_url = get_application_file_download_url(res.resume_url)
    if res.reel_url:
        res.reel_url = get_application_file_download_url(res.reel_url)

    return res


def to_ph_application_response(app: Application) -> ApplicationResponse:
    """Translates canonical database 'submitted' status to Production House 'received' status
    and resolves authorized presigned download URLs for private media.
    """
    return to_authorized_application_response(app, is_ph=True)


async def check_application_access(
    application_id: uuid.UUID,
    current_user: User,
    db: AsyncSession,
) -> Application:
    """Verifies that current_user is either the Talent owner of the application
    or the Production House owner of the opportunity/project associated with the application.
    Returns the Application record if authorized, otherwise raises HTTPException.
    """
    result = await db.execute(select(Application).where(Application.id == application_id))
    app_record = result.scalar_one_or_none()
    if not app_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found")

    # Talent owner access
    if app_record.talent_id == current_user.id:
        return app_record

    # Production House owner access via Opportunity
    if app_record.opportunity_id:
        opp_res = await db.execute(select(Opportunity).where(Opportunity.id == app_record.opportunity_id))
        opp = opp_res.scalar_one_or_none()
        if opp:
            ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.id == opp.production_house_id))
            ph = ph_res.scalar_one_or_none()
            if ph and ph.user_id == current_user.id:
                return app_record

    # Production House owner access via Project
    if app_record.project_id:
        proj_res = await db.execute(select(Project).where(Project.id == app_record.project_id))
        proj = proj_res.scalar_one_or_none()
        if proj:
            ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.id == proj.production_house_id))
            ph = ph_res.scalar_one_or_none()
            if ph and ph.user_id == current_user.id:
                return app_record

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to access private files for this application.",
    )


@router.post("/", response_model=ApplicationResponse, status_code=status.HTTP_201_CREATED)
async def submit_application(
    app_in: ApplicationCreate,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Submit an application to an open opportunity or project (Talent only)."""
    # 1. Target validation
    if app_in.opportunity_id:
        opp_res = await db.execute(select(Opportunity).where(Opportunity.id == app_in.opportunity_id))
        opp = opp_res.scalar_one_or_none()
        if not opp:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Opportunity / Job not found")
        if opp.status != "open":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"This job is currently {opp.status} and is not accepting applications.",
            )

        # Check duplicate
        existing_res = await db.execute(
            select(Application).where(
                Application.opportunity_id == app_in.opportunity_id,
                Application.talent_id == current_user.id,
            )
        )
        if existing_res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already submitted an application for this job.",
            )

    elif app_in.project_id:
        proj_res = await db.execute(select(Project).where(Project.id == app_in.project_id))
        proj = proj_res.scalar_one_or_none()
        if not proj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

        # Check duplicate
        existing_res = await db.execute(
            select(Application).where(
                Application.project_id == app_in.project_id,
                Application.talent_id == current_user.id,
            )
        )
        if existing_res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already submitted an application for this project.",
            )

    # 2. Acquire advisory locks in deterministic sorted order before validating and attaching
    candidate_media = [app_in.resume_url, app_in.reel_url]
    await acquire_media_advisory_locks(db, candidate_media)

    # 3. Validate media ownership and existence for private files while lock is held
    checked_storage_keys = set()
    if app_in.resume_url:
        validate_talent_media_ownership(
            app_in.resume_url,
            current_user.id,
            "resume",
            checked_keys=checked_storage_keys,
        )
    if app_in.reel_url:
        validate_talent_media_ownership(
            app_in.reel_url,
            current_user.id,
            "audition reel",
            checked_keys=checked_storage_keys,
        )

    application = Application(
        opportunity_id=app_in.opportunity_id,
        project_id=app_in.project_id,
        talent_id=current_user.id,
        cover_letter=app_in.cover_letter,
        resume_url=app_in.resume_url,
        reel_url=app_in.reel_url,
        status="submitted",
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)
    application.talent = current_user
    return to_authorized_application_response(application, is_ph=False)


@router.get("/my", response_model=List[ApplicationResponse])
async def list_my_applications(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by application status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """List applications submitted by the logged-in talent user."""
    stmt = (
        select(Application)
        .where(Application.talent_id == current_user.id)
        .options(
            selectinload(Application.opportunity),
            selectinload(Application.project),
            selectinload(Application.talent),
        )
    )
    if status_filter:
        stmt = stmt.where(Application.status == status_filter)
    stmt = stmt.order_by(Application.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    apps = result.scalars().all()
    return [to_authorized_application_response(a, is_ph=False) for a in apps]


@router.get("/", response_model=List[ApplicationResponse])
async def list_applications_for_production_house(
    opportunity_id: Optional[uuid.UUID] = Query(None, description="Filter by opportunity ID"),
    project_id: Optional[uuid.UUID] = Query(None, description="Filter by project ID"),
    target_type: Optional[str] = Query(None, description="Filter by target type: 'project' or 'job'"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """List all candidate applications received by the logged-in production house."""
    res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = res.scalar_one_or_none()
    if not ph:
        return []

    stmt = (
        select(Application)
        .outerjoin(Opportunity, Application.opportunity_id == Opportunity.id)
        .outerjoin(Project, Application.project_id == Project.id)
        .where(
            or_(
                Opportunity.production_house_id == ph.id,
                Project.production_house_id == ph.id,
            )
        )
        .options(
            selectinload(Application.talent),
            selectinload(Application.opportunity),
            selectinload(Application.project),
        )
    )
    if project_id:
        stmt = stmt.where(Application.project_id == project_id)
    if opportunity_id:
        stmt = stmt.where(Application.opportunity_id == opportunity_id)
    if target_type == "project":
        stmt = stmt.where(Application.project_id != None)
    elif target_type in ("job", "opportunity"):
        stmt = stmt.where(Application.opportunity_id != None)

    if status_filter:
        if status_filter.lower() in ("received", "submitted"):
            stmt = stmt.where(Application.status.in_(["submitted", "received"]))
        else:
            stmt = stmt.where(Application.status == status_filter)

    stmt = stmt.order_by(Application.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    apps = result.scalars().all()
    return [to_authorized_application_response(a, is_ph=True) for a in apps]


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
        return to_authorized_application_response(app_record, is_ph=False)

    # If user is production house owner of the opportunity
    if app_record.opportunity_id:
        opp_res = await db.execute(select(Opportunity).where(Opportunity.id == app_record.opportunity_id))
        opp = opp_res.scalar_one_or_none()
        if opp:
            ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.id == opp.production_house_id))
            ph = ph_res.scalar_one_or_none()
            if ph and ph.user_id == current_user.id:
                return to_authorized_application_response(app_record, is_ph=True)

    # If user is production house owner of the project
    if app_record.project_id:
        proj_res = await db.execute(select(Project).where(Project.id == app_record.project_id))
        proj = proj_res.scalar_one_or_none()
        if proj:
            ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.id == proj.production_house_id))
            ph = ph_res.scalar_one_or_none()
            if ph and ph.user_id == current_user.id:
                return to_authorized_application_response(app_record, is_ph=True)

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to view this application.",
    )


@router.get("/{application_id}/resume-download-url", response_model=ApplicationDownloadUrlResponse)
async def get_application_resume_download_url(
    application_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate a temporary presigned download URL for the application's resume (Authorized Talent or PH only)."""
    app_record = await check_application_access(application_id, current_user, db)

    if not app_record.resume_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Application does not have a resume attached.",
        )

    download_url = get_application_file_download_url(app_record.resume_url, expires_in=3600)
    file_key = extract_file_key(app_record.resume_url) or app_record.resume_url

    return ApplicationDownloadUrlResponse(
        download_url=download_url,
        file_key=file_key,
        file_type="resume",
        expires_in_seconds=3600,
    )


@router.get("/{application_id}/reel-download-url", response_model=ApplicationDownloadUrlResponse)
async def get_application_reel_download_url(
    application_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate a temporary presigned download URL for the application's audition reel (Authorized Talent or PH only)."""
    app_record = await check_application_access(application_id, current_user, db)

    if not app_record.reel_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Application does not have an audition reel attached.",
        )

    download_url = get_application_file_download_url(app_record.reel_url, expires_in=3600)
    file_key = extract_file_key(app_record.reel_url) or app_record.reel_url

    return ApplicationDownloadUrlResponse(
        download_url=download_url,
        file_key=file_key,
        file_type="reel",
        expires_in_seconds=3600,
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

    # Capture old values before applying updates
    old_resume_url = app_record.resume_url
    old_reel_url = app_record.reel_url

    patch_dict = app_in.model_dump(exclude_unset=True)

    # Identify new private media keys being attached and acquire advisory locks in sorted order
    new_media_to_lock = []
    if "resume_url" in patch_dict and patch_dict["resume_url"]:
        new_media_to_lock.append(patch_dict["resume_url"])
    if "reel_url" in patch_dict and patch_dict["reel_url"]:
        new_media_to_lock.append(patch_dict["reel_url"])

    if new_media_to_lock:
        await acquire_media_advisory_locks(db, new_media_to_lock)

    # Validate media ownership and existence for private files while lock is held
    checked_storage_keys = set()
    if app_in.resume_url is not None:
        validate_talent_media_ownership(
            app_in.resume_url,
            current_user.id,
            "resume",
            checked_keys=checked_storage_keys,
        )
    if app_in.reel_url is not None:
        validate_talent_media_ownership(
            app_in.reel_url,
            current_user.id,
            "audition reel",
            checked_keys=checked_storage_keys,
        )

    urls_to_cleanup = []

    # Check if resume_url is being replaced or cleared
    if "resume_url" in patch_dict:
        new_resume = patch_dict["resume_url"]
        if old_resume_url:
            old_canon = extract_file_key(old_resume_url)
            new_canon = extract_file_key(new_resume) if new_resume else None
            if old_canon and old_canon != new_canon:
                urls_to_cleanup.append(old_resume_url)

    # Check if reel_url is being replaced or cleared
    if "reel_url" in patch_dict:
        new_reel = patch_dict["reel_url"]
        if old_reel_url:
            old_canon = extract_file_key(old_reel_url)
            new_canon = extract_file_key(new_reel) if new_reel else None
            if old_canon and old_canon != new_canon:
                urls_to_cleanup.append(old_reel_url)

    for field, value in patch_dict.items():
        setattr(app_record, field, value)

    # Commit DB transaction first
    await db.commit()
    await db.refresh(app_record)

    # Perform reference-safe cleanup only after successful commit
    if urls_to_cleanup:
        try:
            await cleanup_unreferenced_application_media(
                db=db,
                urls_to_check=urls_to_cleanup,
                exclude_application_id=app_record.id,
            )
        except Exception as e:
            logger.warning(
                "Application %s updated, but media cleanup encountered an error: %s",
                application_id,
                e,
            )

    app_record.talent = current_user
    return to_authorized_application_response(app_record, is_ph=False)


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

    # 1. Capture media references before deleting the DB record
    old_media_urls = [app_record.resume_url, app_record.reel_url]

    # 2. Delete database record
    await db.delete(app_record)

    # 3. Commit database transaction first
    await db.commit()

    # 4. Perform reference-safe cleanup only after successful commit
    try:
        await cleanup_unreferenced_application_media(
            db=db,
            urls_to_check=old_media_urls,
            exclude_application_id=application_id,
        )
    except Exception as e:
        logger.warning(
            "Application %s withdrawn successfully, but media cleanup encountered an error: %s",
            application_id,
            e,
        )

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

    # Lifecycle rule: Do not allow resetting to received/submitted once in review
    requested_status = status_in.status.lower()
    if requested_status in ("received", "submitted"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot reset application status to received/submitted once under review.",
        )

    VALID_PH_STATUSES = {"under_review", "shortlisted", "rejected", "accepted"}
    if requested_status not in VALID_PH_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status '{status_in.status}'. Allowed statuses: {', '.join(sorted(VALID_PH_STATUSES))}.",
        )

    app_record.status = requested_status
    await db.commit()
    await db.refresh(app_record)
    talent_res = await db.execute(select(User).where(User.id == app_record.talent_id))
    app_record.talent = talent_res.scalar_one_or_none()
    return to_authorized_application_response(app_record, is_ph=True)
