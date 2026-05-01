"""
Chat feature:
  REST  GET  /orders/{id}/messages          — history (last 50)
  REST  GET  /orders/{id}/contact           — counterparty name + phone
  REST  POST /orders/{id}/call              — initiate call (sends FCM to recipient)
  WS        /ws/orders/{id}/chat            — real-time messaging via Redis pub/sub
  WS        /ws/orders/{id}/audio           — audio relay (server as intermediary)
"""
import asyncio
import json
import logging
import uuid

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import current_user
from app.config import get_settings
from app.core.fcm import send_push
from app.core.redis import get_redis
from app.core.security import decode_access_token
from app.database import SessionLocal, get_db
from app.models.chat_message import ChatMessage
from app.models.order import Order, OrderStatus
from app.models.user import User, DeviceToken

logger = logging.getLogger(__name__)
router = APIRouter(tags=["chat"])

# In-memory audio relay rooms: order_id → [websocket, ...] (max 2)
# NOTE: works only with a single Uvicorn worker (no shared state across workers)
_audio_rooms: dict[str, list[WebSocket]] = {}

_ACTIVE_STATUSES = {OrderStatus.accepted, OrderStatus.delivering}


def _chat_channel(order_id: uuid.UUID) -> str:
    return f"shopho:chat:{order_id}"


def _webrtc_channel(order_id: uuid.UUID) -> str:
    return f"shopho:webrtc:{order_id}"


def _fmt(msg: ChatMessage, my_id: uuid.UUID) -> dict:
    return {
        "id": str(msg.id),
        "sender_id": str(msg.sender_id),
        "sender_name": msg.sender.display_name or msg.sender.username if msg.sender else "Ẩn danh",
        "content": msg.content,
        "created_at": msg.created_at.isoformat(),
        "is_me": msg.sender_id == my_id,
    }


# ─── REST: history ──────────────────────────────────────────

@router.get("/orders/{order_id}/messages")
async def get_messages(
    order_id: uuid.UUID,
    limit: int = Query(50, le=100),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    order = await db.scalar(select(Order).where(Order.id == order_id))
    if not order:
        raise HTTPException(404, "Đơn không tồn tại")
    if order.creator_id != user.id and order.shipper_id != user.id:
        raise HTTPException(403, "Không có quyền truy cập")

    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.order_id == order_id)
        .order_by(ChatMessage.created_at.asc())
        .limit(limit)
    )
    return [_fmt(m, user.id) for m in result.scalars().all()]


# ─── REST: initiate call ─────────────────────────────────────

@router.post("/orders/{order_id}/call")
async def initiate_call(
    order_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    order = await db.scalar(select(Order).where(Order.id == order_id))
    if not order:
        raise HTTPException(404, "Đơn không tồn tại")
    if order.status not in _ACTIVE_STATUSES:
        raise HTTPException(400, "Chỉ có thể gọi khi đơn đang được xử lý")

    if order.creator_id == user.id:
        recipient_id = order.shipper_id
    elif order.shipper_id == user.id:
        recipient_id = order.creator_id
    else:
        raise HTTPException(403, "Không có quyền truy cập")

    if not recipient_id:
        raise HTTPException(404, "Chưa có người tiếp nhận")

    rows = await db.execute(
        select(DeviceToken.token).where(DeviceToken.user_id == recipient_id)
    )
    tokens = list(rows.scalars().all())

    caller_name = user.display_name or user.username
    call_id = str(uuid.uuid4())

    # Fetch recipient name to show in caller's call screen
    recipient = await db.scalar(select(User).where(User.id == recipient_id))
    counterpart_name = (recipient.display_name or recipient.username) if recipient else "Đối phương"

    if tokens:
        await send_push(
            tokens=tokens,
            title=f"Cuộc gọi từ {caller_name}",
            body="Đang gọi...",
            data={
                "type": "call",
                "call_id": call_id,
                "order_id": str(order_id),
                "caller_name": caller_name,
            },
            data_only=True,
        )

    return {"order_id": str(order_id), "counterpart_name": counterpart_name}


# ─── REST: contact info ──────────────────────────────────────

@router.get("/orders/{order_id}/contact")
async def get_contact(
    order_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    order = await db.scalar(select(Order).where(Order.id == order_id))
    if not order:
        raise HTTPException(404, "Đơn không tồn tại")
    if order.status not in _ACTIVE_STATUSES:
        raise HTTPException(400, "Chỉ liên hệ khi đơn đang được xử lý")

    if order.creator_id == user.id:
        counterpart = order.shipper
    elif order.shipper_id == user.id:
        counterpart = order.creator
    else:
        raise HTTPException(403, "Không có quyền truy cập")

    if not counterpart:
        raise HTTPException(404, "Chưa có người tiếp nhận đơn")

    return {
        "id": str(counterpart.id),
        "name": counterpart.display_name or counterpart.username,
        "phone": counterpart.phone,
    }


# ─── WebSocket: real-time chat ───────────────────────────────

@router.websocket("/ws/orders/{order_id}/chat")
async def ws_chat(
    websocket: WebSocket,
    order_id: uuid.UUID,
    token: str = Query(...),
):
    # 1. Authenticate
    try:
        user_id = uuid.UUID(decode_access_token(token))
    except (JWTError, ValueError):
        await websocket.close(code=4001)
        return

    # 2. Validate order access
    async with SessionLocal() as db:
        order = await db.scalar(select(Order).where(Order.id == order_id))
        if not order or (order.creator_id != user_id and order.shipper_id != user_id):
            await websocket.close(code=4003)
            return
        if order.status not in _ACTIVE_STATUSES:
            await websocket.close(code=4004)
            return
        user_row = await db.scalar(select(User).where(User.id == user_id))
        sender_name = (user_row.display_name or user_row.username) if user_row else "Ẩn danh"

    await websocket.accept()
    channel = _chat_channel(order_id)

    # 3. Subscribe to per-order Redis channel using the shared pool.
    # Each pubsub() call borrows one connection from the pool for the duration
    # of the subscription, avoiding per-WS pool creation.
    r = await get_redis()
    pubsub = r.pubsub()
    await pubsub.subscribe(channel)

    async def _redis_to_ws() -> None:
        try:
            async for message in pubsub.listen():
                if message["type"] != "message":
                    continue
                try:
                    await websocket.send_text(message["data"])
                except Exception:
                    break
        except asyncio.CancelledError:
            pass

    listener = asyncio.create_task(_redis_to_ws())

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                content = json.loads(raw).get("content", "").strip()
            except (json.JSONDecodeError, AttributeError):
                continue
            if not content:
                continue

            # 4. Persist to DB + collect recipient tokens
            async with SessionLocal() as db:
                msg = ChatMessage(order_id=order_id, sender_id=user_id, content=content)
                db.add(msg)
                await db.flush()
                payload = json.dumps({
                    "id": str(msg.id),
                    "sender_id": str(user_id),
                    "sender_name": sender_name,
                    "content": content,
                    "created_at": msg.created_at.isoformat(),
                })

                # Determine recipient (the other party)
                order_row = await db.scalar(select(Order).where(Order.id == order_id))
                recipient_id = (
                    order_row.creator_id
                    if order_row and order_row.shipper_id == user_id
                    else (order_row.shipper_id if order_row else None)
                )
                tokens: list[str] = []
                if recipient_id:
                    rows = await db.execute(
                        select(DeviceToken.token).where(DeviceToken.user_id == recipient_id)
                    )
                    tokens = list(rows.scalars().all())

                await db.commit()

            # 5. Broadcast via Redis (real-time for open app)
            await r.publish(channel, payload)

            # 6. FCM push (for background/closed app)
            if tokens:
                preview = content if len(content) <= 60 else content[:57] + "..."
                await send_push(
                    tokens=tokens,
                    title=f"Tin nhắn từ {sender_name}",
                    body=preview,
                    data={"order_id": str(order_id), "type": "chat"},
                )

    except WebSocketDisconnect:
        pass
    finally:
        listener.cancel()
        try:
            await pubsub.unsubscribe(channel)
            await pubsub.aclose()  # close only the pubsub, not the shared pool
        except Exception:
            pass
        logger.info("Chat WS disconnected order=%s user=%s", order_id, user_id)


# ─── WebSocket: WebRTC signaling ─────────────────────────────

@router.websocket("/ws/orders/{order_id}/webrtc")
async def ws_webrtc(
    websocket: WebSocket,
    order_id: uuid.UUID,
    token: str = Query(...),
):
    try:
        user_id = uuid.UUID(decode_access_token(token))
    except (JWTError, ValueError):
        await websocket.close(code=4001)
        return

    async with SessionLocal() as db:
        order = await db.scalar(select(Order).where(Order.id == order_id))
        if not order or (order.creator_id != user_id and order.shipper_id != user_id):
            await websocket.close(code=4003)
            return

    await websocket.accept()
    channel = _webrtc_channel(order_id)

    r = await get_redis()
    pubsub = r.pubsub()
    await pubsub.subscribe(channel)

    async def _relay() -> None:
        try:
            async for message in pubsub.listen():
                if message["type"] != "message":
                    continue
                data = json.loads(message["data"])
                # Don't echo back to sender
                if data.pop("_from", None) != str(user_id):
                    try:
                        await websocket.send_text(json.dumps(data))
                    except Exception:
                        break
        except asyncio.CancelledError:
            pass

    listener = asyncio.create_task(_relay())

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            data["_from"] = str(user_id)
            await r.publish(channel, json.dumps(data))
    except WebSocketDisconnect:
        pass
    finally:
        listener.cancel()
        try:
            await pubsub.unsubscribe(channel)
            await pubsub.aclose()
        except Exception:
            pass
        logger.info("WebRTC WS disconnected order=%s user=%s", order_id, user_id)


# ─── WebSocket: audio relay (backend as intermediary) ────────

@router.websocket("/ws/orders/{order_id}/audio")
async def ws_audio(
    websocket: WebSocket,
    order_id: uuid.UUID,
    token: str = Query(...),
):
    try:
        user_id = uuid.UUID(decode_access_token(token))
    except (JWTError, ValueError):
        await websocket.close(code=4001)
        return

    async with SessionLocal() as db:
        order = await db.scalar(select(Order).where(Order.id == order_id))
        if not order or (order.creator_id != user_id and order.shipper_id != user_id):
            await websocket.close(code=4003)
            return

    await websocket.accept()
    room_key = str(order_id)

    if room_key not in _audio_rooms:
        _audio_rooms[room_key] = []
    room = _audio_rooms[room_key]

    if len(room) >= 2:
        await websocket.close(code=4008)  # room full
        return

    room.append(websocket)

    # Notify connection status
    if len(room) == 1:
        await websocket.send_json({"type": "waiting"})
    else:
        for ws in room:
            try:
                await ws.send_json({"type": "start"})
            except Exception:
                pass

    def _peer() -> WebSocket | None:
        return next((ws for ws in room if ws is not websocket), None)

    try:
        while True:
            msg = await websocket.receive()
            if msg.get("type") == "websocket.disconnect":
                break

            peer = _peer()
            if peer is None:
                continue

            if msg.get("bytes"):
                try:
                    await peer.send_bytes(msg["bytes"])
                except Exception:
                    break
            elif msg.get("text"):
                try:
                    data = json.loads(msg["text"])
                    if data.get("type") == "hangup":
                        await peer.send_json({"type": "hangup"})
                        break
                except Exception:
                    pass
    except WebSocketDisconnect:
        pass
    finally:
        if websocket in room:
            room.remove(websocket)
        if not room:
            _audio_rooms.pop(room_key, None)
        else:
            for ws in room:
                try:
                    await ws.send_json({"type": "hangup"})
                except Exception:
                    pass
        logger.info("Audio WS disconnected order=%s user=%s", order_id, user_id)
