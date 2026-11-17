import json
import uuid
from typing import Dict, List
from fastapi import WebSocket, WebSocketDisconnect, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import AsyncSessionLocal
from app.core.security import verify_supabase_jwt
from app.models.message import Message


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

    payload = verify_supabase_jwt(token)
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

                if not recipient_id_str or not body:
                    await websocket.send_text(json.dumps({"error": "Missing recipient_id or body"}))
                    continue

                try:
                    recipient_id = uuid.UUID(recipient_id_str)
                except ValueError:
                    await websocket.send_text(json.dumps({"error": "Invalid recipient_id format"}))
                    continue

                # Persist message to database
                async with AsyncSessionLocal() as session:
                    db_msg = Message(
                        sender_id=user_id,
                        recipient_id=recipient_id,
                        body=body,
                        is_read=False,
                    )
                    session.add(db_msg)
                    await session.commit()
                    await session.refresh(db_msg)

                    outgoing_data = {
                        "event": "new_message",
                        "message_id": str(db_msg.id),
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
