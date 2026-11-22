import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.config import settings
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.social import Reel
from app.schemas.reel import ReelCreate, ReelResponse
from app.schemas.user import TalentSummaryResponse
from app.services.storage import (
    acquire_public_media_advisory_locks,
    validate_public_media_ownership,
    parse_storage_url,
    generate_presigned_download_url,
)

router = APIRouter()


def _format_reel_response(reel: Reel, current_user_id: Optional[uuid.UUID] = None) -> ReelResponse:
    creator_summary = None
    creator_name = "Cinematographer"
    creator_craft = "Camera Dept"
    creator_avatar = "CC"

    if reel.user:
        creator_summary = TalentSummaryResponse.model_validate(reel.user)
        creator_name = reel.user.full_name or "Cinematographer"
        creator_craft = reel.user.role or "Camera Dept"
        parts = creator_name.strip().split()
        if len(parts) >= 2:
            creator_avatar = f"{parts[0][0]}{parts[1][0]}".upper()
        elif len(parts) == 1 and len(parts[0]) > 0:
            creator_avatar = parts[0][:2].upper()

    file_key, bucket, is_internal = parse_storage_url(reel.media_url)
    playback_url = reel.media_url
    if is_internal and file_key:
        try:
            target_bucket = bucket or settings.MINIO_PUBLIC_BUCKET
            playback_url = generate_presigned_download_url(
                bucket_name=target_bucket,
                file_key=file_key,
                expires_in=86400,
            )
        except Exception:
            playback_url = reel.media_url

    res = ReelResponse(
        id=reel.id,
        user_id=reel.user_id,
        title=reel.title,
        caption=reel.caption,
        media_url=reel.media_url,
        thumbnail_url=reel.thumbnail_url,
        playback_url=playback_url,
        audio_track=reel.audio_track,
        smpte_timecode=reel.smpte_timecode,
        craft_specialty=reel.craft_specialty,
        reel_type=reel.reel_type,
        creator_name=creator_name,
        creator_craft=creator_craft,
        creator_avatar=creator_avatar,
        likes_count=0,
        comments_count=0,
        is_liked=False,
        is_bookmarked=False,
        creator=creator_summary,
        created_at=reel.created_at,
        updated_at=reel.updated_at,
    )
    return res


@router.post("/", response_model=ReelResponse, status_code=status.HTTP_201_CREATED)
async def create_reel(
    reel_in: ReelCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Publish a new CineReel vertical showreel."""
    candidate_media = [reel_in.media_url]
    if reel_in.thumbnail_url:
        candidate_media.append(reel_in.thumbnail_url)
    await acquire_public_media_advisory_locks(db, candidate_media)

    checked_keys = set()
    validate_public_media_ownership(
        url_or_key=reel_in.media_url,
        user_id=current_user.id,
        field_name="media_url",
        verify_exists=True,
        checked_keys=checked_keys,
    )
    if reel_in.thumbnail_url:
        validate_public_media_ownership(
            url_or_key=reel_in.thumbnail_url,
            user_id=current_user.id,
            field_name="thumbnail_url",
            verify_exists=True,
            checked_keys=checked_keys,
        )

    reel = Reel(
        user_id=current_user.id,
        title=reel_in.title,
        caption=reel_in.caption,
        media_url=reel_in.media_url,
        thumbnail_url=reel_in.thumbnail_url,
        audio_track=reel_in.audio_track,
        smpte_timecode=reel_in.smpte_timecode,
        craft_specialty=reel_in.craft_specialty,
        reel_type=reel_in.reel_type or "Cinematography Showreel",
    )
    db.add(reel)
    await db.commit()
    await db.refresh(reel)
    reel.user = current_user
    return _format_reel_response(reel, current_user.id)


@router.get("/", response_model=List[ReelResponse])
async def list_reels(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Browse public CineReels vertical feed (newest first)."""
    stmt = (
        select(Reel)
        .order_by(Reel.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    reels = result.scalars().all()
    return [_format_reel_response(r) for r in reels]


@router.get("/my", response_model=List[ReelResponse])
async def list_my_reels(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List CineReels created by the logged-in user."""
    stmt = (
        select(Reel)
        .where(Reel.user_id == current_user.id)
        .order_by(Reel.created_at.desc())
    )
    result = await db.execute(stmt)
    reels = result.scalars().all()
    return [_format_reel_response(r, current_user.id) for r in reels]


@router.get("/{reel_id}", response_model=ReelResponse)
async def get_reel(
    reel_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get single CineReel details."""
    result = await db.execute(select(Reel).where(Reel.id == reel_id))
    reel = result.scalar_one_or_none()
    if not reel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reel not found")
    return _format_reel_response(reel)


@router.get("/{reel_id}/playback-url")
async def get_reel_playback_url(
    reel_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Obtain an authorized playable URL for a CineReel video."""
    result = await db.execute(select(Reel).where(Reel.id == reel_id))
    reel = result.scalar_one_or_none()
    if not reel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reel not found")

    file_key, bucket, is_internal = parse_storage_url(reel.media_url)
    playback_url = reel.media_url
    if is_internal and file_key:
        try:
            target_bucket = bucket or settings.MINIO_PUBLIC_BUCKET
            playback_url = generate_presigned_download_url(
                bucket_name=target_bucket,
                file_key=file_key,
                expires_in=86400,
            )
        except Exception:
            playback_url = reel.media_url
    return {"reel_id": str(reel.id), "playback_url": playback_url}


@router.delete("/{reel_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reel(
    reel_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete an owned CineReel."""
    result = await db.execute(
        select(Reel).where(Reel.id == reel_id, Reel.user_id == current_user.id)
    )
    reel = result.scalar_one_or_none()
    if not reel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reel not found or not owned by you.",
        )
    await db.delete(reel)
    await db.commit()
    return None

