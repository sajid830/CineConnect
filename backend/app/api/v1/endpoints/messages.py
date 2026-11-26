import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_, and_, func, case
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user
from app.api.websocket import manager
from app.models.user import User
from app.models.message import Message
from app.services.chat import get_accepted_collaboration
from app.schemas.message import (
    MessageCreate,
    MessageResponse,
    ConversationSummary,
    UnreadCountResponse,
)

router = APIRouter()


@router.post("/", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(
    msg_in: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Send a direct message to another user with collaboration authorization and duplicate prevention."""
    if msg_in.recipient_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot message yourself.",
        )

    # 1. Idempotency Check: if client_message_id was already processed for this sender
    if msg_in.client_message_id:
        existing_res = await db.execute(
            select(Message).where(
                Message.sender_id == current_user.id,
                Message.client_message_id == msg_in.client_message_id,
            )
        )
        existing_msg = existing_res.scalar_one_or_none()
        if existing_msg:
            return existing_msg

    # 2. Verify recipient exists
    rec_res = await db.execute(select(User).where(User.id == msg_in.recipient_id))
    if not rec_res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipient user not found")

    # 3. Verify accepted collaboration authorization
    collab = await get_accepted_collaboration(db, current_user.id, msg_in.recipient_id)
    if not collab:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Messaging is only allowed between talent and production houses with an accepted collaboration.",
        )

    # 4. Create and persist message
    message = Message(
        sender_id=current_user.id,
        recipient_id=msg_in.recipient_id,
        collaboration_id=collab.id,
        client_message_id=msg_in.client_message_id,
        body=msg_in.body,
        is_read=False,
    )
    db.add(message)
    try:
        await db.commit()
        await db.refresh(message)
    except IntegrityError:
        await db.rollback()
        # Handle concurrent race condition for duplicate client_message_id
        if msg_in.client_message_id:
            existing_res = await db.execute(
                select(Message).where(
                    Message.sender_id == current_user.id,
                    Message.client_message_id == msg_in.client_message_id,
                )
            )
            existing_msg = existing_res.scalar_one_or_none()
            if existing_msg:
                return existing_msg
        raise

    # 5. Broadcast new message event to recipient if connected via WebSocket
    try:
        outgoing_data = {
            "event": "new_message",
            "message_id": str(message.id),
            "client_message_id": message.client_message_id,
            "collaboration_id": str(collab.id),
            "sender_id": str(current_user.id),
            "recipient_id": str(msg_in.recipient_id),
            "body": message.body,
            "created_at": message.created_at.isoformat(),
        }
        await manager.send_personal_message(outgoing_data, msg_in.recipient_id)
    except Exception:
        pass

    return message


@router.get("/conversations", response_model=List[ConversationSummary])
async def list_conversations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List conversation summaries (grouped by conversation partner) with unread counts."""
    # Find all distinct user IDs the current user interacted with
    sent_res = await db.execute(select(Message.recipient_id).where(Message.sender_id == current_user.id).distinct())
    recv_res = await db.execute(select(Message.sender_id).where(Message.recipient_id == current_user.id).distinct())

    partner_ids = set(sent_res.scalars().all()) | set(recv_res.scalars().all())
    summaries: List[ConversationSummary] = []

    for pid in partner_ids:
        # Fetch partner info
        user_res = await db.execute(select(User).where(User.id == pid))
        partner = user_res.scalar_one_or_none()
        if not partner:
            continue

        # Fetch latest message
        latest_res = await db.execute(
            select(Message)
            .where(
                or_(
                    and_(Message.sender_id == current_user.id, Message.recipient_id == pid),
                    and_(Message.sender_id == pid, Message.recipient_id == current_user.id),
                )
            )
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        latest_msg = latest_res.scalar_one_or_none()

        # Count unread messages received from this partner
        unread_res = await db.execute(
            select(func.count(Message.id)).where(
                Message.sender_id == pid,
                Message.recipient_id == current_user.id,
                Message.is_read == False,
            )
        )
        unread_count = unread_res.scalar_one() or 0

        summaries.append(
            ConversationSummary(
                user_id=partner.id,
                full_name=partner.full_name,
                last_message=latest_msg.body if latest_msg else None,
                last_message_at=latest_msg.created_at if latest_msg else None,
                unread_count=unread_count,
            )
        )

    # Sort conversations by latest message timestamp
    summaries.sort(key=lambda s: s.last_message_at or s.last_message_at.min, reverse=True)
    return summaries


@router.get("/conversations/{user_id}", response_model=List[MessageResponse])
async def get_conversation_thread(
    user_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get message history with a specific user, and mark unread incoming messages as read."""
    # 1. Fetch messages
    stmt = (
        select(Message)
        .where(
            or_(
                and_(Message.sender_id == current_user.id, Message.recipient_id == user_id),
                and_(Message.sender_id == user_id, Message.recipient_id == current_user.id),
            )
        )
        .order_by(Message.created_at.asc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    messages = result.scalars().all()

    # 2. Mark unread messages sent by `user_id` to `current_user` as read
    for msg in messages:
        if msg.sender_id == user_id and not msg.is_read:
            msg.is_read = True

    await db.commit()
    return messages


@router.get("/unread-count", response_model=UnreadCountResponse)
async def get_unread_messages_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get total count of unread messages across all conversations."""
    result = await db.execute(
        select(func.count(Message.id)).where(
            Message.recipient_id == current_user.id,
            Message.is_read == False,
        )
    )
    count = result.scalar_one() or 0
    return UnreadCountResponse(unread_count=count)


@router.get("/{message_id}", response_model=MessageResponse)
async def get_message(
    message_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get single message by ID (Sender or recipient only)."""
    result = await db.execute(select(Message).where(Message.id == message_id))
    message = result.scalar_one_or_none()
    if not message:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    if message.sender_id != current_user.id and message.recipient_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this message.",
        )
    return message


@router.delete("/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_message(
    message_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a message (Sender or recipient only)."""
    result = await db.execute(select(Message).where(Message.id == message_id))
    message = result.scalar_one_or_none()
    if not message:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    if message.sender_id != current_user.id and message.recipient_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to delete this message.",
        )

    await db.delete(message)
    await db.commit()
    return None
