import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.api.dependencies import get_current_user, get_optional_current_user
from app.models.user import User
from app.models.social import Post, Interaction, Bookmark
from app.schemas.post import PostCreate, PostUpdate, PostResponse
from app.schemas.interaction import InteractionResponse, InteractionPatch
from app.schemas.bookmark import BookmarkResponse
from app.schemas.user import TalentSummaryResponse
from app.services.storage import (
    acquire_public_media_advisory_locks,
    validate_public_media_ownership,
    cleanup_unreferenced_public_media,
)

router = APIRouter()


async def _enrich_post_response(post: Post, current_user_id: Optional[uuid.UUID] = None, db: Optional[AsyncSession] = None) -> PostResponse:
    author_name = "Filmmaker"
    author_craft = "Direction"
    author_avatar = "CC"
    guild_badge = "Verified Guild"
    author_summary = None

    if post.user:
        author_summary = TalentSummaryResponse.model_validate(post.user)
        author_name = post.user.full_name or "Filmmaker"
        author_craft = post.user.role or "Direction"
        guild_badge = f"{post.user.guild_id} • Verified" if post.user.guild_id else "Verified Guild"
        parts = author_name.strip().split()
        if len(parts) >= 2:
            author_avatar = f"{parts[0][0]}{parts[1][0]}".upper()
        elif len(parts) == 1 and len(parts[0]) > 0:
            author_avatar = parts[0][:2].upper()

    likes_count = 0
    comments_count = 0
    is_liked = False
    like_interaction_id: Optional[uuid.UUID] = None
    is_bookmarked = False

    if hasattr(post, "interactions") and post.interactions:
        for i in post.interactions:
            if i.type == "like":
                likes_count += 1
                if current_user_id and i.user_id == current_user_id:
                    is_liked = True
                    like_interaction_id = i.id
            elif i.type == "comment":
                comments_count += 1
    elif db:
        likes_res = await db.execute(
            select(func.count(Interaction.id)).where(Interaction.post_id == post.id, Interaction.type == "like")
        )
        likes_count = likes_res.scalar_one() or 0

        comments_res = await db.execute(
            select(func.count(Interaction.id)).where(Interaction.post_id == post.id, Interaction.type == "comment")
        )
        comments_count = comments_res.scalar_one() or 0

        if current_user_id:
            user_like_res = await db.execute(
                select(Interaction).where(Interaction.post_id == post.id, Interaction.user_id == current_user_id, Interaction.type == "like")
            )
            user_like_item = user_like_res.scalar_one_or_none()
            if user_like_item:
                is_liked = True
                like_interaction_id = user_like_item.id

    if current_user_id and db:
        bm_res = await db.execute(
            select(Bookmark).where(Bookmark.post_id == post.id, Bookmark.user_id == current_user_id)
        )
        is_bookmarked = bm_res.scalar_one_or_none() is not None

    return PostResponse(
        id=post.id,
        user_id=post.user_id,
        caption=post.caption,
        media_url=post.media_url,
        video_slate_title=post.video_slate_title,
        smpte_timecode=post.smpte_timecode,
        aspect_ratio=post.aspect_ratio or "2.39:1",
        tags=post.tags,
        author_name=author_name,
        author_craft=author_craft,
        author_avatar=author_avatar,
        guild_badge=guild_badge,
        likes_count=likes_count,
        comments_count=comments_count,
        is_liked=is_liked,
        like_interaction_id=like_interaction_id,
        is_bookmarked=is_bookmarked,
        author=author_summary,
        created_at=post.created_at,
        updated_at=post.updated_at,
    )


@router.post("/", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(
    post_in: PostCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new cinema feed post."""
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
        video_slate_title=post_in.video_slate_title,
        smpte_timecode=post_in.smpte_timecode,
        aspect_ratio=post_in.aspect_ratio or "2.39:1",
        tags=post_in.tags,
    )
    db.add(post)
    await db.commit()
    await db.refresh(post)
    post.user = current_user
    return await _enrich_post_response(post, current_user.id, db)


@router.get("/bookmarks/my", response_model=List[PostResponse])
async def list_my_bookmarked_posts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List posts bookmarked by the logged-in user."""
    stmt = (
        select(Post)
        .join(Bookmark, Bookmark.post_id == Post.id)
        .where(Bookmark.user_id == current_user.id)
        .options(selectinload(Post.user), selectinload(Post.interactions))
        .order_by(Bookmark.created_at.desc())
    )
    result = await db.execute(stmt)
    posts = result.scalars().all()
    return [await _enrich_post_response(p, current_user.id, db) for p in posts]


@router.post("/{post_id}/bookmark", status_code=status.HTTP_201_CREATED)
async def bookmark_post(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Bookmark a post."""
    post_res = await db.execute(select(Post).where(Post.id == post_id))
    if not post_res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")

    existing_res = await db.execute(
        select(Bookmark).where(Bookmark.user_id == current_user.id, Bookmark.post_id == post_id)
    )
    if existing_res.scalar_one_or_none():
        return {"status": "already_bookmarked"}

    bm = Bookmark(user_id=current_user.id, post_id=post_id)
    db.add(bm)
    await db.commit()
    return {"status": "bookmarked", "post_id": str(post_id)}


@router.delete("/{post_id}/bookmark", status_code=status.HTTP_204_NO_CONTENT)
async def remove_bookmark(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove a bookmark from a post."""
    bm_res = await db.execute(
        select(Bookmark).where(Bookmark.user_id == current_user.id, Bookmark.post_id == post_id)
    )
    bm = bm_res.scalar_one_or_none()
    if bm:
        await db.delete(bm)
        await db.commit()
    return None


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
        .options(selectinload(Post.user), selectinload(Post.interactions))
        .order_by(Post.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    posts = result.scalars().all()
    return [await _enrich_post_response(p, current_user.id, db) for p in posts]


@router.get("/", response_model=List[PostResponse])
async def list_posts(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all feed posts (public timeline, newest first)."""
    stmt = (
        select(Post)
        .options(selectinload(Post.user), selectinload(Post.interactions))
        .order_by(Post.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    posts = result.scalars().all()
    user_id = current_user.id if current_user else None
    return [await _enrich_post_response(p, user_id, db) for p in posts]


@router.get("/{post_id}", response_model=PostResponse)
async def get_post(
    post_id: uuid.UUID,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get single post by ID."""
    stmt = (
        select(Post)
        .where(Post.id == post_id)
        .options(selectinload(Post.user), selectinload(Post.interactions))
    )
    result = await db.execute(stmt)
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    user_id = current_user.id if current_user else None
    return await _enrich_post_response(post, user_id, db)


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
