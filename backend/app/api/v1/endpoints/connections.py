import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.social import Connection
from app.schemas.connection import ConnectionCreate, ConnectionResponse, FollowToggleResponse

router = APIRouter()


@router.post("/toggle/{target_user_id}", response_model=FollowToggleResponse, status_code=status.HTTP_200_OK)
async def toggle_follow_user(
    target_user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """1-Tap Instagram-style Follow/Unfollow toggle.
    Any talent or production house can follow any talent or production house.
    """
    if target_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot follow yourself.",
        )

    # Verify target user exists
    target_res = await db.execute(select(User).where(User.id == target_user_id))
    target_user = target_res.scalar_one_or_none()
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target user not found")

    # Check if current user is already following target
    existing_res = await db.execute(
        select(Connection).where(
            Connection.sender_id == current_user.id,
            Connection.receiver_id == target_user_id,
            Connection.deleted_at.is_(None),
        )
    )
    existing = existing_res.scalar_one_or_none()

    if existing:
        # Unfollow: delete or remove connection
        await db.delete(existing)
        await db.commit()
        is_following = False
    else:
        # Follow: create accepted connection immediately
        new_conn = Connection(
            sender_id=current_user.id,
            receiver_id=target_user_id,
            status="accepted",
        )
        db.add(new_conn)
        await db.commit()
        is_following = True

    # Compute target's updated followers and following counts
    followers_cnt = (
        await db.execute(
            select(func.count(Connection.id)).where(
                Connection.receiver_id == target_user_id,
                Connection.status == "accepted",
                Connection.deleted_at.is_(None),
            )
        )
    ).scalar() or 0

    following_cnt = (
        await db.execute(
            select(func.count(Connection.id)).where(
                Connection.sender_id == target_user_id,
                Connection.status == "accepted",
                Connection.deleted_at.is_(None),
            )
        )
    ).scalar() or 0

    return FollowToggleResponse(
        target_user_id=target_user_id,
        is_following=is_following,
        followers_count=followers_cnt,
        following_count=following_cnt,
    )


@router.get("/status/{target_user_id}", response_model=FollowToggleResponse)
async def get_follow_status(
    target_user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Check follow status between current user and target user."""
    conn_res = await db.execute(
        select(Connection).where(
            Connection.sender_id == current_user.id,
            Connection.receiver_id == target_user_id,
            Connection.status == "accepted",
            Connection.deleted_at.is_(None),
        )
    )
    is_following = conn_res.scalar_one_or_none() is not None

    followers_cnt = (
        await db.execute(
            select(func.count(Connection.id)).where(
                Connection.receiver_id == target_user_id,
                Connection.status == "accepted",
                Connection.deleted_at.is_(None),
            )
        )
    ).scalar() or 0

    following_cnt = (
        await db.execute(
            select(func.count(Connection.id)).where(
                Connection.sender_id == target_user_id,
                Connection.status == "accepted",
                Connection.deleted_at.is_(None),
            )
        )
    ).scalar() or 0

    return FollowToggleResponse(
        target_user_id=target_user_id,
        is_following=is_following,
        followers_count=followers_cnt,
        following_count=following_cnt,
    )


@router.post("/", response_model=ConnectionResponse, status_code=status.HTTP_201_CREATED)
async def send_connection_request(
    conn_in: ConnectionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Send a connection / follow to another user."""
    if conn_in.receiver_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot connect with yourself.",
        )

    # Verify target user exists
    target_res = await db.execute(select(User).where(User.id == conn_in.receiver_id))
    if not target_res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target user not found")

    # Check existing connection in this direction
    existing_res = await db.execute(
        select(Connection).where(
            Connection.sender_id == current_user.id,
            Connection.receiver_id == conn_in.receiver_id,
            Connection.deleted_at.is_(None),
        )
    )
    existing = existing_res.scalar_one_or_none()
    if existing:
        if existing.status == "accepted":
            return existing
        existing.status = "accepted"
        await db.commit()
        await db.refresh(existing)
        return existing

    connection = Connection(
        sender_id=current_user.id,
        receiver_id=conn_in.receiver_id,
        status="accepted",
    )
    db.add(connection)
    await db.commit()
    await db.refresh(connection)
    return connection


@router.get("/my", response_model=List[ConnectionResponse])
async def list_my_connections(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    status: Optional[str] = Query("accepted", description="Filter by status ('accepted', 'pending', 'all')"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all connections of the logged-in user."""
    stmt = (
        select(Connection)
        .where(
            or_(Connection.sender_id == current_user.id, Connection.receiver_id == current_user.id),
        )
    )
    if status and status != "all":
        stmt = stmt.where(Connection.status == status)
    stmt = stmt.order_by(Connection.updated_at.desc()).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/requests", response_model=List[ConnectionResponse])
async def list_pending_requests(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List pending connection requests received by the logged-in user."""
    stmt = (
        select(Connection)
        .where(
            and_(
                Connection.receiver_id == current_user.id,
                Connection.status == "pending",
            )
        )
        .order_by(Connection.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{connection_id}", response_model=ConnectionResponse)
async def get_connection(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get single connection details (Sender or receiver only)."""
    result = await db.execute(select(Connection).where(Connection.id == connection_id))
    connection = result.scalar_one_or_none()
    if not connection:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found")

    if connection.sender_id != current_user.id and connection.receiver_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this connection.",
        )
    return connection


@router.patch("/{connection_id}/accept", response_model=ConnectionResponse)
async def accept_connection(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Accept an incoming connection request (Receiver only)."""
    result = await db.execute(
        select(Connection).where(
            Connection.id == connection_id,
            Connection.receiver_id == current_user.id,
        )
    )
    connection = result.scalar_one_or_none()
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pending connection request not found for your account.",
        )

    connection.status = "accepted"
    await db.commit()
    await db.refresh(connection)
    return connection


@router.patch("/{connection_id}/reject", response_model=ConnectionResponse)
async def reject_connection(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Reject an incoming connection request (Receiver only)."""
    result = await db.execute(
        select(Connection).where(
            Connection.id == connection_id,
            Connection.receiver_id == current_user.id,
        )
    )
    connection = result.scalar_one_or_none()
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pending connection request not found for your account.",
        )

    connection.status = "rejected"
    await db.commit()
    await db.refresh(connection)
    return connection


@router.delete("/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_connection(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove a connection or cancel a sent request (Sender or receiver only)."""
    result = await db.execute(
        select(Connection).where(
            Connection.id == connection_id,
            or_(Connection.sender_id == current_user.id, Connection.receiver_id == current_user.id),
        )
    )
    connection = result.scalar_one_or_none()
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection not found or you do not have permission to delete it.",
        )

    await db.delete(connection)
    await db.commit()
    return None
