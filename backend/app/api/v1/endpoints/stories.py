import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.config import settings
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.social import Story
from app.schemas.story import StoryCreate, StoryResponse
from app.schemas.user import TalentSummaryResponse
from app.services.storage import (
    acquire_public_media_advisory_locks,
    validate_public_media_ownership,
    parse_storage_url,
    generate_presigned_download_url,
    cleanup_unreferenced_public_media,
)

router = APIRouter()


def _format_story_response(story: Story) -> StoryResponse:
    creator_summary = None
    creator_name = "You"
    initials = "CC"

    if story.user:
        creator_summary = TalentSummaryResponse.model_validate(story.user)
        creator_name = story.user.full_name or "Talent"
        parts = creator_name.strip().split()
        if len(parts) >= 2:
            initials = f"{parts[0][0]}{parts[1][0]}".upper()
        elif len(parts) == 1 and len(parts[0]) > 0:
            initials = parts[0][:2].upper()

    now = datetime.now(timezone.utc)
    story_created = story.created_at
    if story_created.tzinfo is None:
        story_created = story_created.replace(tzinfo=timezone.utc)
    diff = now - story_created
    if diff.total_seconds() < 60:
        time_ago = "Just now"
    elif diff.total_seconds() < 3600:
        time_ago = f"{int(diff.total_seconds() // 60)}m ago"
    else:
        time_ago = f"{int(diff.total_seconds() // 3600)}h ago"

    file_key, bucket, is_internal = parse_storage_url(story.media_url)
    playback_url = story.media_url
    if is_internal and file_key:
        try:
            target_bucket = bucket or settings.MINIO_PUBLIC_BUCKET
            playback_url = generate_presigned_download_url(
                bucket_name=target_bucket,
                file_key=file_key,
                expires_in=86400,
            )
        except Exception:
            playback_url = story.media_url

    return StoryResponse(
        id=story.id,
        user_id=story.user_id,
        media_url=story.media_url,
        playback_url=playback_url,
        caption=story.caption,
        location=story.location or "Film Set",
        craft_badge=story.craft_badge or "Film Crew",
        creator_name=creator_name,
        initials=initials,
        time_ago=time_ago,
        has_unseen=True,
        creator=creator_summary,
        created_at=story.created_at,
        expires_at=story.expires_at,
    )


@router.post("/", response_model=StoryResponse, status_code=status.HTTP_201_CREATED)
async def create_story(
    story_in: StoryCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Publish an on-set story that automatically expires after 24 hours."""
    await acquire_public_media_advisory_locks(db, [story_in.media_url])
    validate_public_media_ownership(
        url_or_key=story_in.media_url,
        user_id=current_user.id,
        field_name="media_url",
        verify_exists=True,
    )

    now = datetime.now(timezone.utc)
    expires = now + timedelta(hours=24)

    story = Story(
        user_id=current_user.id,
        media_url=story_in.media_url,
        caption=story_in.caption,
        location=story_in.location or current_user.location or "On Set",
        craft_badge=story_in.craft_badge or current_user.role or "Talent",
        created_at=now,
        expires_at=expires,
    )
    db.add(story)
    await db.commit()
    await db.refresh(story)
    story.user = current_user
    return _format_story_response(story)


@router.get("/", response_model=List[StoryResponse])
async def list_active_stories(
    db: AsyncSession = Depends(get_db),
):
    """Retrieve all non-expired on-set stories (strictly created within the last 24h)."""
    now = datetime.now(timezone.utc)
    stmt = (
        select(Story)
        .where(Story.expires_at > now)
        .order_by(Story.created_at.desc())
    )
    result = await db.execute(stmt)
    stories = result.scalars().all()
    return [_format_story_response(s) for s in stories]


@router.get("/my", response_model=List[StoryResponse])
async def list_my_stories(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List active stories published by the current user."""
    now = datetime.now(timezone.utc)
    stmt = (
        select(Story)
        .where(Story.user_id == current_user.id, Story.expires_at > now)
        .order_by(Story.created_at.desc())
    )
    result = await db.execute(stmt)
    stories = result.scalars().all()
    return [_format_story_response(s) for s in stories]


@router.get("/{story_id}/playback-url")
async def get_story_playback_url(
    story_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Retrieve a fresh presigned playback/download URL for an active story."""
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(Story).where(Story.id == story_id, Story.expires_at > now)
    )
    story = result.scalar_one_or_none()
    if not story:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found or has expired.",
        )

    file_key, bucket, is_internal = parse_storage_url(story.media_url)
    if is_internal and file_key:
        try:
            target_bucket = bucket or settings.MINIO_PUBLIC_BUCKET
            url = generate_presigned_download_url(
                bucket_name=target_bucket,
                file_key=file_key,
                expires_in=86400,
            )
            return {"playback_url": url, "media_url": story.media_url, "expires_in": 86400}
        except Exception:
            pass

    return {"playback_url": story.media_url, "media_url": story.media_url, "expires_in": 86400}


@router.delete("/{story_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_story(
    story_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete an owned story."""
    result = await db.execute(
        select(Story).where(Story.id == story_id, Story.user_id == current_user.id)
    )
    story = result.scalar_one_or_none()
    if not story:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Story not found or not owned by you.",
        )
    media_url = story.media_url
    await db.delete(story)
    await db.commit()
    try:
        await cleanup_unreferenced_public_media(db, [media_url])
    except Exception:
        pass
    return None
