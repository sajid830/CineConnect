import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.social import Post, Interaction
from app.schemas.post import PostCreate, PostUpdate, PostResponse
from app.schemas.interaction import InteractionResponse, InteractionPatch
from app.services.storage import (
    acquire_public_media_advisory_locks,
    validate_public_media_ownership,
    cleanup_unreferenced_public_media,
)

router = APIRouter()


@router.post("/", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(
    post_in: PostCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new feed post."""
    if post_in.media_url:
        await acquire_public_media_advisory_locks(db, [post_in.media_url])
        validate_public_media_ownership(
            url_or_key=post_in.media_url,
            user_id=current_user.id,
            field_name="media_url",
            verify_exists=True,
        )

    post = Post(
        user_id=current_user.id,
        caption=post_in.caption,
        media_url=post_in.media_url,
    )
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return post


@router.get("/my", response_model=List[PostResponse])
async def list_my_posts(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List posts created by the logged-in user."""
    stmt = (
        select(Post)
        .where(Post.user_id == current_user.id)
        .order_by(Post.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/", response_model=List[PostResponse])
async def list_posts(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """List all feed posts (public timeline, newest first)."""
    stmt = select(Post).order_by(Post.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{post_id}", response_model=PostResponse)
async def get_post(
    post_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get single post by ID."""
    result = await db.execute(select(Post).where(Post.id == post_id))
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    return post


@router.put("/{post_id}", response_model=PostResponse)
async def update_post(
    post_id: uuid.UUID,
    post_in: PostUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update post caption/media (Owner only)."""
    result = await db.execute(
        select(Post).where(
            Post.id == post_id,
            Post.user_id == current_user.id,
        )
    )
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found or you do not have permission to edit it.",
        )

    old_media_url = post.media_url

    if post_in.media_url and post_in.media_url != old_media_url:
        await acquire_public_media_advisory_locks(db, [post_in.media_url])
        validate_public_media_ownership(
            url_or_key=post_in.media_url,
            user_id=current_user.id,
            field_name="media_url",
            verify_exists=True,
        )

    for field, value in post_in.model_dump().items():
        setattr(post, field, value)

    await db.commit()
    await db.refresh(post)

    if old_media_url and old_media_url != post_in.media_url:
        await cleanup_unreferenced_public_media(db=db, urls_to_check=[old_media_url])

    return post


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete post (Owner only)."""
    result = await db.execute(
        select(Post).where(
            Post.id == post_id,
            Post.user_id == current_user.id,
        )
    )
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found or you do not have permission to delete it.",
        )

    old_media_url = post.media_url

    await db.delete(post)
    await db.commit()

    if old_media_url:
        await cleanup_unreferenced_public_media(db=db, urls_to_check=[old_media_url])

    return None


# -----------------------------------------------------------------------------
# Post Interactions Endpoints: GET & POST /api/v1/posts/{post_id}/interactions
# -----------------------------------------------------------------------------
@router.get("/{post_id}/interactions", response_model=List[InteractionResponse], tags=["Interactions", "Social Posts"])
async def list_post_interactions(
    post_id: uuid.UUID,
    type_filter: Optional[str] = Query(None, alias="type", description="Filter by 'like' or 'comment'"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """List all interactions (likes and comments) on a specific post."""
    post_res = await db.execute(select(Post).where(Post.id == post_id))
    if not post_res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")

    stmt = select(Interaction).where(Interaction.post_id == post_id)
    if type_filter:
        stmt = stmt.where(Interaction.type == type_filter)
    stmt = stmt.order_by(Interaction.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/{post_id}/interactions", response_model=InteractionResponse, status_code=status.HTTP_201_CREATED, tags=["Interactions", "Social Posts"])
async def create_post_interaction(
    post_id: uuid.UUID,
    interaction_in: InteractionPatch,
    type_param: str = Query("comment", alias="type", description="'like' or 'comment'"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create an interaction (like or comment) on a specific post."""
    post_res = await db.execute(select(Post).where(Post.id == post_id))
    post = post_res.scalar_one_or_none()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")

    interaction = Interaction(
        post_id=post_id,
        user_id=current_user.id,
        type=type_param,
        comment=interaction_in.comment,
    )
    db.add(interaction)
    await db.commit()
    await db.refresh(interaction)
    return interaction
