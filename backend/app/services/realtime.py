import asyncio
import json
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Set
from fastapi import WebSocket

from app.core.config import settings
from app.core.logging import logger


class RealtimeEventPooler:
    """Asynchronous event pooler and WebSocket dispatcher for instant release/application sync.

    Maintains active WebSocket connections keyed by user ID, queues mutation events
    without blocking HTTP handlers, dispatches them concurrently via asyncio.gather,
    and sends periodic heartbeats to keep mobile/tunnel connections warm.
    """

    def __init__(self) -> None:
        self._connections: Dict[uuid.UUID, List[WebSocket]] = {}
        self._queue: Optional[asyncio.Queue[Dict[str, Any]]] = None
        self._dispatch_task: Optional[asyncio.Task[None]] = None
        self._heartbeat_task: Optional[asyncio.Task[None]] = None
        self._running: bool = False

    async def connect(self, user_id: uuid.UUID, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections.setdefault(user_id, []).append(websocket)

    def disconnect(self, user_id: uuid.UUID, websocket: WebSocket) -> None:
        sockets = self._connections.get(user_id)
        if not sockets:
            return
        if websocket in sockets:
            sockets.remove(websocket)
        if not sockets:
            self._connections.pop(user_id, None)

    @property
    def active_connection_count(self) -> int:
        return sum(len(sockets) for sockets in self._connections.values())

    def start(self) -> None:
        """Starts background async dispatcher and heartbeat loops (idempotent)."""
        if self._running:
            return
        self._running = True
        self._queue = asyncio.Queue()
        self._dispatch_task = asyncio.create_task(self._dispatch_loop(), name="realtime-event-dispatcher")
        self._heartbeat_task = asyncio.create_task(self._heartbeat_loop(), name="realtime-event-heartbeat")
        logger.info(
            "RealtimeEventPooler started (heartbeat=%ss).",
            settings.REALTIME_HEARTBEAT_SECONDS,
        )

    async def stop(self) -> None:
        """Stops background tasks cleanly on application shutdown."""
        self._running = False
        tasks = [t for t in (self._dispatch_task, self._heartbeat_task) if t is not None]
        for task in tasks:
            task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        self._dispatch_task = None
        self._heartbeat_task = None
        self._queue = None
        logger.info("RealtimeEventPooler stopped.")

    def trigger_event(
        self,
        event: str,
        payload: Optional[Dict[str, Any]] = None,
        target_user_ids: Optional[Iterable[Optional[uuid.UUID]]] = None,
    ) -> None:
        """Non-blocking event trigger called right after DB commit.

        Enqueues the event for immediate async fan-out, or schedules a direct
        background task when running without lifespan (e.g. unit test clients).
        """
        targets: Optional[Set[uuid.UUID]] = None
        if target_user_ids is not None:
            targets = {uid for uid in target_user_ids if uid is not None}
            if not targets:
                return

        envelope = {
            "event": event,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            **(payload or {}),
        }
        item = {"envelope": envelope, "targets": targets}

        if self._running and self._queue is not None:
            try:
                self._queue.put_nowait(item)
                return
            except Exception as exc:
                logger.warning(f"Realtime queue put failed for '{event}': {exc}")

        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self._deliver_item(item))
        except RuntimeError:
            # No active event loop; ignore cleanly
            pass

    async def _dispatch_loop(self) -> None:
        assert self._queue is not None
        while self._running:
            try:
                item = await self._queue.get()
                await self._deliver_item(item)
                self._queue.task_done()
            except asyncio.CancelledError:
                break
            except Exception as exc:
                logger.warning(f"Realtime dispatch loop error: {exc}")

    async def _heartbeat_loop(self) -> None:
        interval = max(5, settings.REALTIME_HEARTBEAT_SECONDS)
        while self._running:
            try:
                await asyncio.sleep(interval)
                if self._connections:
                    await self._deliver_item(
                        {
                            "envelope": {
                                "event": "heartbeat",
                                "timestamp": datetime.now(timezone.utc).isoformat(),
                            },
                            "targets": None,
                        }
                    )
            except asyncio.CancelledError:
                break
            except Exception as exc:
                logger.warning(f"Realtime heartbeat loop error: {exc}")

    async def _deliver_item(self, item: Dict[str, Any]) -> None:
        if not self._connections:
            return

        message_text = json.dumps(item["envelope"], default=str)
        targets: Optional[Set[uuid.UUID]] = item.get("targets")

        if targets is None:
            recipients = [
                (uid, ws)
                for uid, sockets in list(self._connections.items())
                for ws in list(sockets)
            ]
        else:
            recipients = [
                (uid, ws)
                for uid in targets
                for ws in list(self._connections.get(uid, ()))
            ]

        if not recipients:
            return

        async def _send_safe(uid: uuid.UUID, ws: WebSocket) -> Optional[tuple[uuid.UUID, WebSocket]]:
            try:
                await ws.send_text(message_text)
                return None
            except Exception:
                return (uid, ws)

        results = await asyncio.gather(*(_send_safe(uid, ws) for uid, ws in recipients))
        for dead in results:
            if dead is not None:
                self.disconnect(dead[0], dead[1])


realtime_pooler = RealtimeEventPooler()
