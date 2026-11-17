import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.social import Post, Interaction
from app.schemas.interaction import (
    InteractionCreate,
    InteractionPatch,
    InteractionResponse,
)

router = APIRouter()


@router.post("/", response_model=InteractionResponse, status_code=status.HTTP_201_CREATED)
async def create_interaction(
    interaction_in: InteractionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a like or comment to a post."""
    post_res = await db.execute(select(Post).where(Post.id == interaction_in.post_id))
    post = post_res.scalar_one_or_none()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")

    interaction = Interaction(
        post_id=interaction_in.post_id,
        user_id=current_user.id,
        type=interaction_in.type,
        comment=interaction_in.comment,
    )
    db.add(interaction)
    await db.commit()
    await db.refresh(interaction)
    return interaction


@router.get("/my", response_model=List[InteractionResponse])
async def list_my_interactions(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List interactions made by the logged-in user."""
    stmt = (
        select(Interaction)
        .where(Interaction.user_id == current_user.id)
        .order_by(Interaction.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{interaction_id}", response_model=InteractionResponse)
async def get_interaction(
    interaction_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get single interaction details."""
    result = await db.execute(select(Interaction).where(Interaction.id == interaction_id))
    interaction = result.scalar_one_or_none()
    if not interaction:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Interaction not found")
    return interaction


@router.patch("/{interaction_id}", response_model=InteractionResponse)
async def patch_interaction(
    interaction_id: uuid.UUID,
    interaction_in: InteractionPatch,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update interaction comment (Owner only)."""
    result = await db.execute(
        select(Interaction).where(
            Interaction.id == interaction_id,
            Interaction.user_id == current_user.id,
        )
    )
    interaction = result.scalar_one_or_none()
    if not interaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Interaction not found or you do not have permission to edit it.",
        )

    if interaction_in.comment is not None:
        interaction.comment = interaction_in.comment

    await db.commit()
    await db.refresh(interaction)
    return interaction


@router.delete("/{interaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_interaction(
    interaction_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete interaction (unlike or remove comment) (Owner only)."""
    result = await db.execute(
        select(Interaction).where(
            Interaction.id == interaction_id,
            Interaction.user_id == current_user.id,
        )
    )
    interaction = result.scalar_one_or_none()
    if not interaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Interaction not found or you do not have permission to delete it.",
        )

    await db.delete(interaction)
    await db.commit()
    return None
