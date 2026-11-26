import json
import uuid
from datetime import datetime, timezone
from uuid import UUID
from unittest.mock import AsyncMock
import pytest
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import app
import app.api.websocket as ws_module


# ==============================================================================
# Mock Session Fixture to prevent any database contention or dev DB writes
# ==============================================================================

@pytest.fixture(autouse=True)
def mock_websocket_db(monkeypatch):
    """Mocks AsyncSessionLocal inside websocket module and init_db in main to guarantee fast in-memory
    execution and 100% isolation from live databases.
    """
    async def _mock_init_db():
        return True

    monkeypatch.setattr("app.main.init_db", _mock_init_db)

    class MockResult:
        def __init__(self, value=None):
            self._value = value

        def scalar_one_or_none(self):
            return self._value

    class MockSession:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            pass

        def add(self, obj):
            if not getattr(obj, "id", None):
                obj.id = uuid.uuid4()
            if not getattr(obj, "created_at", None):
                obj.created_at = datetime.now(timezone.utc)

        async def commit(self):
            pass

        async def rollback(self):
            pass

        async def refresh(self, obj):
            pass

        async def execute(self, statement):
            # If checking recipient user existence, return a mock user
            stmt_str = str(statement)
            if "users" in stmt_str.lower():
                mock_user = type("MockUser", (), {"id": uuid.uuid4()})()
                return MockResult(mock_user)
            # Default for message lookup (e.g. idempotency check) is None
            return MockResult(None)

    monkeypatch.setattr(ws_module, "AsyncSessionLocal", MockSession)


# ==============================================================================
# Authentication & Policy Violation Tests
# ==============================================================================

def test_websocket_missing_token_rejected():
    """Verifies connecting without token query parameter closes with 1008 Policy Violation."""
    client = TestClient(app)
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws/chat"):
            pass
    assert exc_info.value.code == 1008


def test_websocket_invalid_token_rejected():
    """Verifies connecting with a malformed token closes with 1008 Policy Violation."""
    client = TestClient(app)
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws/chat?token=invalid.jwt.signature"):
            pass
    assert exc_info.value.code == 1008


def test_websocket_expired_token_rejected(expired_token: str):
    """Verifies connecting with an expired token closes with 1008 Policy Violation."""
    client = TestClient(app)
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect(f"/ws/chat?token={expired_token}"):
            pass
    assert exc_info.value.code == 1008


# ==============================================================================
# Handshake & Ping-Pong
# ==============================================================================

def test_websocket_authenticated_connection_and_handshake(
    talent_token: str,
    talent_user_id: UUID,
):
    """Verifies authenticated connection receives 'connected' event with user_id."""
    client = TestClient(app)
    with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
        handshake = ws.receive_json()
        assert handshake["event"] == "connected"
        assert handshake["user_id"] == str(talent_user_id)
        assert handshake["status"] == "online"

        # Verify ping-pong keepalive
        ws.send_json({"type": "ping"})
        pong = ws.receive_json()
        assert pong == {"type": "pong"}


# ==============================================================================
# Payload Validation & Error Handling
# ==============================================================================

def test_websocket_missing_fields_in_message_payload(talent_token: str):
    """Verifies error responses when body or recipient_id is missing."""
    client = TestClient(app)
    with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
        ws.receive_json()  # Handshake

        # Missing body
        ws.send_json({"type": "message", "recipient_id": str(uuid.uuid4())})
        err_res1 = ws.receive_json()
        assert "Missing recipient_id or body" in err_res1.get("error", "")

        # Missing recipient_id
        ws.send_json({"type": "message", "body": "Hello World"})
        err_res2 = ws.receive_json()
        assert "Missing recipient_id or body" in err_res2.get("error", "")


def test_websocket_invalid_recipient_uuid_format(talent_token: str):
    """Verifies error message when recipient_id is not a valid UUID."""
    client = TestClient(app)
    with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
        ws.receive_json()  # Handshake

        ws.send_json({"type": "message", "recipient_id": "not-a-valid-uuid", "body": "Hello"})
        err_res = ws.receive_json()
        assert "Invalid recipient_id format" in err_res.get("error", "")


def test_websocket_non_json_payload_ignored_gracefully(talent_token: str):
    """Verifies that sending non-JSON text payloads does not crash the WebSocket connection."""
    client = TestClient(app)
    with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
        ws.receive_json()  # Handshake

        # Send invalid non-JSON string
        ws.send_text("MALFORMED NON-JSON STRING {{{{")

        # Connection remains healthy and handles subsequent valid frames
        ws.send_json({"type": "ping"})
        pong = ws.receive_json()
        assert pong == {"type": "pong"}


# ==============================================================================
# Message Delivery & Real-Time Broadcast
# ==============================================================================

def test_websocket_send_message_rejected_without_accepted_collaboration(
    talent_token: str,
    talent2_user_id: UUID,
    monkeypatch,
):
    """Verifies that sending a WebSocket message without an accepted collaboration is rejected."""
    client = TestClient(app)

    # get_accepted_collaboration returns None
    async def mock_no_collab(*args, **kwargs):
        return None

    monkeypatch.setattr(ws_module, "get_accepted_collaboration", mock_no_collab)

    with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
        ws.receive_json()  # Handshake

        ws.send_json({
            "type": "message",
            "recipient_id": str(talent2_user_id),
            "body": "Unauthorized hello!",
        })

        err_res = ws.receive_json()
        assert "Unauthorized" in err_res.get("error", "")


def test_websocket_send_message_echo_and_realtime_recipient_delivery(
    talent_token: str,
    talent_user_id: UUID,
    talent2_user_id: UUID,
    monkeypatch,
):
    """Verifies message sending produces echo to sender and real-time delivery to recipient."""
    client = TestClient(app)

    # Mock accepted collaboration
    mock_collab = type("MockCollaboration", (), {"id": uuid.uuid4()})()
    async def mock_has_collab(*args, **kwargs):
        return mock_collab

    monkeypatch.setattr(ws_module, "get_accepted_collaboration", mock_has_collab)

    # Register mock WebSocket connection for recipient in ConnectionManager
    mock_recipient_ws = AsyncMock()
    ws_module.manager.active_connections[talent2_user_id] = [mock_recipient_ws]

    try:
        with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
            ws.receive_json()  # Handshake

            # Sender sends message
            ws.send_json({
                "type": "message",
                "recipient_id": str(talent2_user_id),
                "body": "Audition confirmed for Monday morning!",
                "client_message_id": "ws-client-msg-123",
            })

            # Sender receives echo confirmation
            echo = ws.receive_json()
            assert echo["event"] == "new_message"
            assert echo["sender_id"] == str(talent_user_id)
            assert echo["recipient_id"] == str(talent2_user_id)
            assert echo["body"] == "Audition confirmed for Monday morning!"
            assert echo["client_message_id"] == "ws-client-msg-123"
            assert "message_id" in echo
            assert "created_at" in echo

            # Verify recipient's active connection was sent the message payload
            mock_recipient_ws.send_text.assert_called_once()
            called_arg = json.loads(mock_recipient_ws.send_text.call_args[0][0])
            assert called_arg["event"] == "new_message"
            assert called_arg["body"] == "Audition confirmed for Monday morning!"
            assert called_arg["sender_id"] == str(talent_user_id)
            assert called_arg["client_message_id"] == "ws-client-msg-123"
    finally:
        # Cleanup mock connection
        if talent2_user_id in ws_module.manager.active_connections:
            del ws_module.manager.active_connections[talent2_user_id]


# ==============================================================================
# Disconnect & Reconnect Lifecycle
# ==============================================================================

def test_websocket_disconnect_and_reconnect(talent_token: str, talent_user_id: UUID):
    """Verifies that disconnecting and reconnecting works cleanly with connection manager."""
    client = TestClient(app)

    # First connection
    with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
        h = ws.receive_json()
        assert h["event"] == "connected"
        assert talent_user_id in ws_module.manager.active_connections

    # After context exit, user is cleanly unregistered
    assert talent_user_id not in ws_module.manager.active_connections

    # Second connection (reconnect)
    with client.websocket_connect(f"/ws/chat?token={talent_token}") as ws:
        h = ws.receive_json()
        assert h["event"] == "connected"
        assert talent_user_id in ws_module.manager.active_connections
