import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user, require_talent
from app.models.user import User
from app.models.portfolio import PortfolioMedia
from app.schemas.portfolio import (
    PortfolioMediaCreate,
    PortfolioMediaUpdate,
    PortfolioMediaResponse,
)

router = APIRouter()


@router.post("/", response_model=PortfolioMediaResponse, status_code=status.HTTP_201_CREATED)
async def create_portfolio_item(
    item_in: PortfolioMediaCreate,
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Add a new media asset (video, headshot, reel, audio) to talent portfolio."""
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
    return media


@router.get("/my", response_model=List[PortfolioMediaResponse])
async def list_my_portfolio(
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """List portfolio items of the logged-in talent."""
    stmt = select(PortfolioMedia).where(PortfolioMedia.user_id == current_user.id).order_by(PortfolioMedia.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


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
    return media


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

    for field, value in item_in.model_dump().items():
        setattr(media, field, value)

    await db.commit()
    await db.refresh(media)
    return media


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

    await db.delete(media)
    await db.commit()
    return None
