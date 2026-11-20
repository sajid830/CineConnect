import asyncio
import json
import uuid
import websockets
from app.core.security import create_test_token

async def test_websocket():
    print("Testing WebSocket /ws/chat...")
    user_id = str(uuid.uuid4())
    token = create_test_token(user_id=user_id, email="ws_tester@cineconnect.test")

    uri = f"ws://localhost:8000/ws/chat?token={token}"
    async with websockets.connect(uri) as ws:
        # 1. Receive connected event
        greeting = await ws.recv()
        data = json.loads(greeting)
        assert data.get("event") == "connected", f"Expected connected event, got {data}"
        print("  ✓ WebSocket Connected handshake received:", data)

        # 2. Ping-pong test
        await ws.send(json.dumps({"type": "ping"}))
        pong = await ws.recv()
        pong_data = json.loads(pong)
        assert pong_data.get("type") == "pong", f"Expected pong, got {pong_data}"
        print("  ✓ WebSocket ping-pong verified:", pong_data)

    print("WebSocket /ws/chat passed all tests!")

if __name__ == "__main__":
    asyncio.run(test_websocket())
