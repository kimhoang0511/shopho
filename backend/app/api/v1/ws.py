"""
WebSocket endpoint – real-time order events for all connected clients.
Architecture:
  - Each connected Flutter client subscribes to this endpoint.
  - The backend publishes events to Redis pub/sub channel.
  - A single asyncio task per server instance listens to Redis and
    broadcasts to all local WebSocket connections.
  - Works correctly in multi-worker setups because Redis acts as the
    message bus between workers.
"""
import asyncio
import json
import logging

import redis.asyncio as aioredis
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import JWTError

from app.config import get_settings
from app.core.redis import ORDER_CHANNEL, get_redis
from app.core.security import decode_access_token

logger = logging.getLogger(__name__)
router = APIRouter(tags=["websocket"])

# Local registry of connected sockets on this worker
_connections: set[WebSocket] = set()
_listener_task: asyncio.Task | None = None


async def _redis_listener() -> None:
    """Long-running task: receive from Redis, fan-out to local websockets."""
    settings = get_settings()
    r = aioredis.from_url(settings.redis_url, decode_responses=True)
    pubsub = r.pubsub()
    await pubsub.subscribe(ORDER_CHANNEL)
    logger.info("WebSocket Redis listener started")
    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue
            dead: set[WebSocket] = set()
            for ws in list(_connections):
                try:
                    await ws.send_text(message["data"])
                except Exception:
                    dead.add(ws)
            _connections.difference_update(dead)
    except asyncio.CancelledError:
        pass
    finally:
        await pubsub.unsubscribe(ORDER_CHANNEL)
        await r.aclose()
        logger.info("WebSocket Redis listener stopped")


def ensure_listener_running() -> None:
    global _listener_task
    if _listener_task is None or _listener_task.done():
        _listener_task = asyncio.create_task(_redis_listener())


@router.websocket("/ws/orders")
async def ws_orders(websocket: WebSocket):
    # Authenticate via query-param token (Flutter can't set headers on WS)
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4001)
        return
    try:
        decode_access_token(token)
    except JWTError:
        await websocket.close(code=4001)
        return

    await websocket.accept()
    ensure_listener_running()
    _connections.add(websocket)
    logger.info("WS client connected. Total: %d", len(_connections))

    try:
        # Keep connection alive; client sends pings
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        _connections.discard(websocket)
        logger.info("WS client disconnected. Total: %d", len(_connections))
