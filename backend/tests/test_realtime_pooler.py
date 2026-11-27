import asyncio
import json
import unittest
import uuid
from unittest.mock import AsyncMock

from app.db.session import get_pool_status
from app.services.realtime import RealtimeEventPooler


class TestRealtimeEventPooler(unittest.IsolatedAsyncioTestCase):
    async def test_broadcast_and_targeted_event_dispatch(self):
        pooler = RealtimeEventPooler()
        pooler.start()
        try:
            user_a = uuid.uuid4()
            user_b = uuid.uuid4()
            ws_a = AsyncMock()
            ws_b = AsyncMock()

            await pooler.connect(user_a, ws_a)
            await pooler.connect(user_b, ws_b)
            self.assertEqual(pooler.active_connection_count, 2)

            # Broadcast opportunity release to all listeners
            pooler.trigger_event(
                "opportunity_released",
                {"opportunity_id": "opp-1", "status": "open"},
            )
            await asyncio.sleep(0.05)

            self.assertEqual(ws_a.send_text.await_count, 1)
            self.assertEqual(ws_b.send_text.await_count, 1)
            payload_a = json.loads(ws_a.send_text.await_args.args[0])
            self.assertEqual(payload_a["event"], "opportunity_released")
            self.assertEqual(payload_a["opportunity_id"], "opp-1")

            # Targeted application event only reaches user_a
            pooler.trigger_event(
                "application_created",
                {"application_id": "app-1"},
                target_user_ids=[user_a],
            )
            await asyncio.sleep(0.05)

            self.assertEqual(ws_a.send_text.await_count, 2)
            self.assertEqual(ws_b.send_text.await_count, 1)
        finally:
            await pooler.stop()

    async def test_dead_socket_is_pruned(self):
        pooler = RealtimeEventPooler()
        pooler.start()
        try:
            user_id = uuid.uuid4()
            dead_ws = AsyncMock()
            dead_ws.send_text.side_effect = RuntimeError("closed")

            await pooler.connect(user_id, dead_ws)
            self.assertEqual(pooler.active_connection_count, 1)

            pooler.trigger_event("project_released", {"project_id": "proj-1"})
            await asyncio.sleep(0.05)

            self.assertEqual(pooler.active_connection_count, 0)
        finally:
            await pooler.stop()

    def test_pool_status_metadata(self):
        status = get_pool_status()
        self.assertIn("pool_timeout_seconds", status)
        self.assertIn("pool_recycle_seconds", status)
        self.assertIn("pool_use_lifo", status)
        self.assertIn("command_timeout_seconds", status)
