import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.config import settings
from app.api.dependencies import get_current_user, require_talent
from app.models.user import User
from app.models.portfolio import PortfolioMedia
from app.schemas.portfolio import (
    PortfolioMediaCreate,
    PortfolioMediaUpdate,
    PortfolioMediaResponse,
)
from app.services.storage import (
    acquire_public_media_advisory_locks,
    validate_public_media_ownership,
    cleanup_unreferenced_public_media,
    parse_storage_url,
    generate_presigned_download_url,
)

router = APIRouter()


def format_portfolio_response(media: PortfolioMedia) -> PortfolioMediaResponse:
    file_key, bucket, is_internal = parse_storage_url(media.media_url)
    playback_url = media.media_url
    if is_internal and file_key:
        try:
            target_bucket = bucket or settings.MINIO_PUBLIC_BUCKET
            playback_url = generate_presigned_download_url(
                bucket_name=target_bucket,
                file_key=file_key,
                expires_in=86400,
            )
        except Exception:
            playback_url = media.media_url
    return PortfolioMediaResponse(
        id=media.id,
        user_id=media.user_id,
        title=media.title,
        description=media.description,
        media_type=media.media_type,
        media_url=media.media_url,
        thumbnail_url=media.thumbnail_url,
        playback_url=playback_url,
        created_at=media.created_at,
    )


@router.post("/", response_model=PortfolioMediaResponse, status_code=status.HTTP_201_CREATED)
async def create_portfolio_item(
    item_in: PortfolioMediaCreate,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Add a new media asset (video, headshot, reel, audio) to talent portfolio."""
    candidate_media = [item_in.media_url, item_in.thumbnail_url]
    await acquire_public_media_advisory_locks(db, candidate_media)

    checked_keys = set()
    validate_public_media_ownership(
        url_or_key=item_in.media_url,
        user_id=current_user.id,
        field_name="media_url",
        verify_exists=True,
        checked_keys=checked_keys,
    )
    if item_in.thumbnail_url:
        validate_public_media_ownership(
            url_or_key=item_in.thumbnail_url,
            user_id=current_user.id,
            field_name="thumbnail_url",
            verify_exists=True,
            checked_keys=checked_keys,
        )

    media = PortfolioMedia(
        user_id=current_user.id,
        title=item_in.title,
        description=item_in.description,
        media_type=item_in.media_type,
        media_url=item_in.media_url,
        thumbnail_url=item_in.thumbnail_url,
    )
    db.add(media)
    await db.commit()
    await db.refresh(media)
    return format_portfolio_response(media)


@router.get("/my", response_model=List[PortfolioMediaResponse])
async def list_my_portfolio(
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """List portfolio items of the logged-in talent."""
    stmt = select(PortfolioMedia).where(PortfolioMedia.user_id == current_user.id).order_by(PortfolioMedia.created_at.desc())
    result = await db.execute(stmt)
    return [format_portfolio_response(m) for m in result.scalars().all()]


@router.get("/{media_id}/download-url")
async def get_portfolio_download_url(
    media_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Obtain an authorized playable/downloadable URL for a portfolio asset."""
    result = await db.execute(select(PortfolioMedia).where(PortfolioMedia.id == media_id))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio media item not found")

    file_key, bucket, is_internal = parse_storage_url(media.media_url)
    playback_url = media.media_url
    if is_internal and file_key:
        try:
            target_bucket = bucket or settings.MINIO_PUBLIC_BUCKET
            playback_url = generate_presigned_download_url(
                bucket_name=target_bucket,
                file_key=file_key,
                expires_in=86400,
            )
        except Exception:
            playback_url = media.media_url
    return {"media_id": str(media.id), "playback_url": playback_url, "media_url": media.media_url}


@router.get("/{media_id}", response_model=PortfolioMediaResponse)
async def get_portfolio_item(
    media_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get single portfolio media item details."""
    result = await db.execute(select(PortfolioMedia).where(PortfolioMedia.id == media_id))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio media item not found")
    return format_portfolio_response(media)


@router.put("/{media_id}", response_model=PortfolioMediaResponse)
async def update_portfolio_item(
    media_id: uuid.UUID,
    item_in: PortfolioMediaUpdate,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Update portfolio media item (Owner only)."""
    result = await db.execute(
        select(PortfolioMedia).where(
            PortfolioMedia.id == media_id,
            PortfolioMedia.user_id == current_user.id,
        )
    )
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Portfolio item not found or you do not have permission to edit it.",
        )

    old_media_url = media.media_url
    old_thumb_url = media.thumbnail_url

    candidate_new_media = [item_in.media_url, item_in.thumbnail_url]
    await acquire_public_media_advisory_locks(db, candidate_new_media)

    checked_keys = set()
    validate_public_media_ownership(
        url_or_key=item_in.media_url,
        user_id=current_user.id,
        field_name="media_url",
        verify_exists=True,
        checked_keys=checked_keys,
    )
    if item_in.thumbnail_url:
        validate_public_media_ownership(
            url_or_key=item_in.thumbnail_url,
            user_id=current_user.id,
            field_name="thumbnail_url",
            verify_exists=True,
            checked_keys=checked_keys,
        )

    for field, value in item_in.model_dump().items():
        setattr(media, field, value)

    await db.commit()
    await db.refresh(media)

    # Clean up replaced or cleared old media files
    urls_to_cleanup = []
    if old_media_url and old_media_url != item_in.media_url:
        urls_to_cleanup.append(old_media_url)
    if old_thumb_url and old_thumb_url != item_in.thumbnail_url:
        urls_to_cleanup.append(old_thumb_url)

    if urls_to_cleanup:
        await cleanup_unreferenced_public_media(db=db, urls_to_check=urls_to_cleanup)

    return format_portfolio_response(media)


@router.delete("/{media_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_portfolio_item(
    media_id: uuid.UUID,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Delete portfolio media item (Owner only)."""
    result = await db.execute(
        select(PortfolioMedia).where(
            PortfolioMedia.id == media_id,
            PortfolioMedia.user_id == current_user.id,
        )
    )
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Portfolio item not found or you do not have permission to delete it.",
        )

    old_media_url = media.media_url
    old_thumb_url = media.thumbnail_url

    await db.delete(media)
    await db.commit()

    # Clean up unreferenced media files from public storage
    urls_to_cleanup = [u for u in [old_media_url, old_thumb_url] if u]
    if urls_to_cleanup:
        await cleanup_unreferenced_public_media(db=db, urls_to_check=urls_to_cleanup)

    return None
