import json
import uuid
from typing import Dict, List
from fastapi import WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import AsyncSessionLocal
from app.core.security import verify_supabase_jwt
from app.models.user import User
from app.models.message import Message
from app.services.chat import get_accepted_collaboration


class ConnectionManager:
    """Manages active WebSocket connections mapped by user ID."""

    def __init__(self):
        self.active_connections: Dict[uuid.UUID, List[WebSocket]] = {}

    async def connect(self, user_id: uuid.UUID, websocket: WebSocket):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, user_id: uuid.UUID, websocket: WebSocket):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_personal_message(self, message: dict, user_id: uuid.UUID):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_text(json.dumps(message))
                except Exception:
                    pass

    async def broadcast(self, message: dict):
        for connections in self.active_connections.values():
            for connection in connections:
                try:
                    await connection.send_text(json.dumps(message))
                except Exception:
                    pass


manager = ConnectionManager()


async def chat_websocket_endpoint(websocket: WebSocket, token: str = None):
    """
    WebSocket endpoint for real-time messaging.
    Connect with: ws://localhost:8000/ws/chat?token=<jwt_token>
    """
    # 1. Authenticate via token query parameter
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    payload = await verify_supabase_jwt(token)
    if not payload:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    sub = payload.get("sub")
    if not sub:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    try:
        user_id = uuid.UUID(sub)
    except ValueError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(user_id, websocket)

    # Send connected acknowledgment
    await websocket.send_text(json.dumps({
        "event": "connected",
        "user_id": str(user_id),
        "status": "online"
    }))

    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg_payload = json.loads(data)
            except Exception:
                continue

            event_type = msg_payload.get("type", "message")

            # Handle ping / keepalive
            if event_type == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))
                continue

            if event_type == "message":
                recipient_id_str = msg_payload.get("recipient_id")
                body = msg_payload.get("body", "").strip()
                client_msg_id = msg_payload.get("client_message_id")

                if not recipient_id_str or not body:
                    await websocket.send_text(json.dumps({"error": "Missing recipient_id or body"}))
                    continue

                try:
                    recipient_id = uuid.UUID(recipient_id_str)
                except ValueError:
                    await websocket.send_text(json.dumps({"error": "Invalid recipient_id format"}))
                    continue

                if recipient_id == user_id:
                    await websocket.send_text(json.dumps({"error": "You cannot message yourself."}))
                    continue

                async with AsyncSessionLocal() as session:
                    # 1. Idempotency Check
                    if client_msg_id:
                        existing_res = await session.execute(
                            select(Message).where(
                                Message.sender_id == user_id,
                                Message.client_message_id == client_msg_id,
                            )
                        )
                        existing_msg = existing_res.scalar_one_or_none()
                        if existing_msg:
                            echo_data = {
                                "event": "new_message",
                                "message_id": str(existing_msg.id),
                                "client_message_id": existing_msg.client_message_id,
                                "collaboration_id": str(existing_msg.collaboration_id) if existing_msg.collaboration_id else None,
                                "sender_id": str(user_id),
                                "recipient_id": str(recipient_id),
                                "body": existing_msg.body,
                                "created_at": existing_msg.created_at.isoformat(),
                            }
                            await websocket.send_text(json.dumps(echo_data))
                            continue

                    # 2. Verify recipient exists
                    rec_res = await session.execute(select(User).where(User.id == recipient_id))
                    if not rec_res.scalar_one_or_none():
                        await websocket.send_text(json.dumps({"error": "Recipient user not found"}))
                        continue

                    # 3. Verify accepted collaboration authorization
                    collab = await get_accepted_collaboration(session, user_id, recipient_id)
                    if not collab:
                        await websocket.send_text(json.dumps({
                            "error": "Unauthorized: Messaging is only allowed between talent and production houses with an accepted collaboration."
                        }))
                        continue

                    # 4. Persist message to database
                    db_msg = Message(
                        sender_id=user_id,
                        recipient_id=recipient_id,
                        collaboration_id=collab.id,
                        client_message_id=client_msg_id,
                        body=body,
                        is_read=False,
                    )
                    session.add(db_msg)
                    try:
                        await session.commit()
                        await session.refresh(db_msg)
                    except IntegrityError:
                        await session.rollback()
                        if client_msg_id:
                            existing_res = await session.execute(
                                select(Message).where(
                                    Message.sender_id == user_id,
                                    Message.client_message_id == client_msg_id,
                                )
                            )
                            existing_msg = existing_res.scalar_one_or_none()
                            if existing_msg:
                                db_msg = existing_msg
                            else:
                                continue
                        else:
                            continue

                    outgoing_data = {
                        "event": "new_message",
                        "message_id": str(db_msg.id),
                        "client_message_id": db_msg.client_message_id,
                        "collaboration_id": str(collab.id),
                        "sender_id": str(user_id),
                        "recipient_id": str(recipient_id),
                        "body": db_msg.body,
                        "created_at": db_msg.created_at.isoformat(),
                    }

                    # Echo to sender
                    await websocket.send_text(json.dumps(outgoing_data))

                    # Deliver to recipient in real time if online
                    await manager.send_personal_message(outgoing_data, recipient_id)

    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception:
        manager.disconnect(user_id, websocket)
