"""
Core business logic for orders.
All writes use SELECT ... FOR UPDATE to prevent race conditions at scale.
"""
import asyncio
import logging
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.redis import cache_delete, publish_event
from app.models.order import Order, OrderImage, OrderStatus, ShipLocationType, VALIDITY_OPTIONS
from app.models.user import DeviceToken, ShipperAlert, User
from app.core.fcm import send_push
from app.schemas.order import OrderCreate, OrderListItem, OrderResponse
from app.services.gold_service import GoldError, adjust_gold_for_order_edit, bonus_gold_on_completion, dispute_gold, lock_gold_for_order, partial_refund_on_delivery, reduce_gold_in_delivery, refund_creator, refund_creator_on_accepted_cancel, refund_creator_on_shipper_cancel, reward_shipper

logger = logging.getLogger(__name__)


def _alert_matches(
    alert: ShipperAlert,
    ship_apartment_id: uuid.UUID | None,
    ship_building: str | None,
    ship_floor: int | None,
) -> bool:
    """Return True if the new order's location falls within this shipper's browse filter."""
    apt_ids: list[str] = alert.apartment_ids or []
    b_keys: list[str] = alert.building_keys or []
    floors: list[int] = alert.floors or []

    apt_id_str = str(ship_apartment_id) if ship_apartment_id else None

    matched = False
    if apt_id_str and apt_id_str in apt_ids:
        matched = True
    if apt_id_str and ship_building and f"{apt_id_str}:{ship_building}" in b_keys:
        matched = True

    if not matched:
        return False

    # If shipper filtered by specific floors, order must declare a matching floor
    if floors:
        return ship_floor is not None and ship_floor in floors

    return True


async def _push_new_order_alerts(
    *,
    order_id: uuid.UUID,
    ship_apartment_id: uuid.UUID | None,
    ship_building: str | None,
    ship_floor: int | None,
    creator_id: uuid.UUID,
    note: str,
    gold_reward: float,
) -> None:
    """Background task: FCM push to shippers with a matching enabled browse-alert.

    Uses 2 queries total (alerts + batch token fetch) instead of 1+N.
    """
    from app.database import SessionLocal

    # Brief delay so the calling transaction can commit first
    await asyncio.sleep(0.2)
    try:
        async with SessionLocal() as db:
            # Query 1: all enabled alerts
            alerts_res = await db.execute(
                select(ShipperAlert).where(ShipperAlert.enabled.is_(True))
            )
            matching_user_ids = [
                alert.user_id
                for alert in alerts_res.scalars().all()
                if alert.user_id != creator_id
                and _alert_matches(alert, ship_apartment_id, ship_building, ship_floor)
            ]

            if not matching_user_ids:
                return

            # Query 2: batch-fetch all device tokens in one IN query
            tokens_res = await db.execute(
                select(DeviceToken.token).where(
                    DeviceToken.user_id.in_(matching_user_ids)
                )
            )
            tokens = list(tokens_res.scalars().all())
            if tokens:
                await send_push(
                    tokens,
                    "Có đơn hàng mới!",
                    f"Gold: {gold_reward:.0f} · {note[:60]}",
                    {"order_id": str(order_id), "type": "new_order"},
                )
    except Exception as exc:
        logger.error("_push_new_order_alerts failed: %s", exc)


class OrderError(Exception):
    def __init__(self, detail: str, status_code: int = 400):
        self.detail = detail
        self.status_code = status_code


# ─── helpers ────────────────────────────────────────────────

async def _push(db: AsyncSession, user_id: uuid.UUID, title: str, body: str, order_id: uuid.UUID) -> None:
    result = await db.execute(select(DeviceToken).where(DeviceToken.user_id == user_id))
    tokens = [row.token for row in result.scalars().all()]
    await send_push(tokens, title, body, {"order_id": str(order_id)})

def _calc_expires(validity_option: str) -> datetime:
    minutes = VALIDITY_OPTIONS[validity_option]
    return datetime.now(timezone.utc) + timedelta(minutes=minutes)


async def _get_order_or_404(db: AsyncSession, order_id: uuid.UUID) -> Order:
    order = await db.scalar(
        select(Order)
        .options(selectinload(Order.images), selectinload(Order.creator), selectinload(Order.shipper))
        .where(Order.id == order_id)
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    return order


async def _invalidate_order_cache() -> None:
    await cache_delete("shopho:orders:pending:list")


# ─── CREATE ─────────────────────────────────────────────────

async def create_order(
    db: AsyncSession,
    creator: User,
    data: OrderCreate,
    image_keys: list[tuple[str, str]],   # [(storage_key, public_url), ...]
) -> Order:
    # Validate location fields
    if data.ship_location in (ShipLocationType.floor, ShipLocationType.room):
        if data.ship_floor is None:
            raise OrderError("Cần nhập tầng cho vị trí ship này")
    if data.ship_location == ShipLocationType.room:
        if not data.ship_room:
            raise OrderError("Cần nhập số phòng cho vị trí ship này")

    order = Order(
        creator_id=creator.id,
        note=data.note,
        gold_reward=data.gold_reward,
        ship_apartment_id=creator.apartment_id,
        ship_location=data.ship_location,
        ship_building=data.ship_building or creator.apt_building,
        ship_floor=data.ship_floor,
        ship_room=data.ship_room,
        validity_option=data.validity_option,
        expires_at=_calc_expires(data.validity_option),
        status=OrderStatus.pending,
    )
    db.add(order)
    await db.flush()   # get order.id

    # Attach images
    for idx, (key, url) in enumerate(image_keys):
        db.add(OrderImage(order_id=order.id, storage_key=key, public_url=url, sort_order=idx))

    # Lock gold from creator – raises GoldError if insufficient funds
    try:
        await lock_gold_for_order(db, creator.id, order.id, data.gold_reward)
    except GoldError as e:
        raise OrderError(e.detail, e.status_code)

    await db.flush()

    # Broadcast new order event to all listening shippers
    await publish_event("order_created", {
        "order_id": str(order.id),
        "note": order.note,
        "gold_reward": float(order.gold_reward),
        "ship_building": order.ship_building,
        "ship_location": order.ship_location.value,
        "ship_apartment_id": str(order.ship_apartment_id) if order.ship_apartment_id else None,
    })
    await _invalidate_order_cache()

    # Push FCM to shippers whose browse-alert filter matches this order.
    # Runs in background after commit so it doesn't delay the response.
    asyncio.create_task(
        _push_new_order_alerts(
            order_id=order.id,
            ship_apartment_id=order.ship_apartment_id,
            ship_building=order.ship_building,
            ship_floor=order.ship_floor,
            creator_id=creator.id,
            note=order.note,
            gold_reward=float(order.gold_reward),
        )
    )

    # Reload with relationships so FastAPI can serialize without lazy-load errors
    return await _get_order_or_404(db, order.id)


# ─── LIST (shippers browsing) ────────────────────────────────

async def list_pending_orders(
    db: AsyncSession,
    apartment_ids: list[uuid.UUID] | None = None,
    building_pairs: list[tuple[uuid.UUID, str]] | None = None,
    floors: list[int] | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[Order]:
    now = datetime.now(timezone.utc)
    q = (
        select(Order)
        .options(selectinload(Order.images), selectinload(Order.creator))
        .where(Order.status == OrderStatus.pending, Order.expires_at > now)
        .order_by(Order.created_at.desc())
        .limit(limit)
        .offset(offset)
    )

    conditions = []
    if apartment_ids:
        conditions.append(Order.ship_apartment_id.in_(apartment_ids))
    if building_pairs:
        for apt_id, building in building_pairs:
            conditions.append(
                (Order.ship_apartment_id == apt_id) & (Order.ship_building == building)
            )
    if conditions:
        q = q.where(or_(*conditions))

    if floors:
        # Include lobby-only orders (ship_location=building) alongside floor matches
        q = q.where(
            or_(
                Order.ship_floor.in_(floors),
                Order.ship_location == ShipLocationType.building,
            )
        )

    result = await db.execute(q)
    return list(result.scalars().all())


# ─── UPDATE ─────────────────────────────────────────────────

async def update_order(
    db: AsyncSession,
    user: User,
    order_id: uuid.UUID,
    note: str,
    gold_reward: float,
    ship_location: ShipLocationType,
    validity_option: str,
    image_keys: list[tuple[str, str]] | None,  # None = keep existing
) -> Order:
    from sqlalchemy import delete as sa_delete

    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.creator_id != user.id:
        raise OrderError("Bạn không có quyền sửa đơn này", 403)
    if order.status != OrderStatus.pending:
        raise OrderError("Chỉ có thể sửa đơn đang ở trạng thái chờ", 400)

    order.note = note.strip()
    order.ship_location = ship_location

    if validity_option != order.validity_option:
        order.validity_option = validity_option
        order.expires_at = _calc_expires(validity_option)

    if gold_reward != float(order.gold_reward):
        try:
            await adjust_gold_for_order_edit(db, user.id, order.id, float(order.gold_reward), gold_reward)
        except GoldError as e:
            raise OrderError(e.detail, e.status_code)
        order.gold_reward = gold_reward

    if image_keys is not None:
        await db.execute(sa_delete(OrderImage).where(OrderImage.order_id == order.id))
        for idx, (key, url) in enumerate(image_keys):
            db.add(OrderImage(order_id=order.id, storage_key=key, public_url=url, sort_order=idx))

    await db.flush()
    await _invalidate_order_cache()
    return await _get_order_or_404(db, order.id)


# ─── ACCEPT ─────────────────────────────────────────────────

async def accept_order(db: AsyncSession, shipper: User, order_id: uuid.UUID, estimated_minutes: int | None = None) -> tuple[Order, float]:
    """
    Race-condition safe: uses SELECT FOR UPDATE then checks status.
    Only the first shipper wins; subsequent calls raise OrderError.
    """
    now = datetime.now(timezone.utc)

    result = await db.execute(
        select(Order)
        .where(Order.id == order_id)
        .with_for_update(skip_locked=True)   # non-blocking; losers get nothing
    )
    order = result.scalar_one_or_none()

    if not order:
        raise OrderError("Đơn đã được nhận bởi người khác, vui lòng chọn đơn khác", 409)
    if order.status != OrderStatus.pending:
        raise OrderError("Đơn không còn ở trạng thái chờ", 409)
    if order.expires_at <= now:
        raise OrderError("Đơn đã hết hiệu lực", 410)
    if order.creator_id == shipper.id:
        raise OrderError("Bạn không thể nhận đơn của chính mình", 400)

    order.status = OrderStatus.accepted
    order.shipper_id = shipper.id
    order.accepted_at = now
    order.estimated_minutes = estimated_minutes
    if estimated_minutes is not None:
        order.estimated_delivery_at = now + timedelta(minutes=estimated_minutes)

    # Gold stays locked – will be rewarded to shipper only when creator confirms completion
    await db.flush()
    await db.refresh(shipper)

    await publish_event("order_accepted", {
        "order_id": str(order.id),
        "shipper_id": str(shipper.id),
    })
    await _invalidate_order_cache()
    await _push(db, order.creator_id, "Đơn hàng đã được nhận", f"{shipper.display_name or shipper.username} đã nhận đơn của bạn", order.id)

    return await _get_order_or_404(db, order.id), float(shipper.gold_balance)


# ─── SHIPPER: CONFIRM DELIVERY ───────────────────────────────

async def shipper_confirm_delivery(
    db: AsyncSession,
    shipper: User,
    order_id: uuid.UUID,
    adjusted_gold: float | None = None,
) -> Order:
    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.shipper_id != shipper.id:
        raise OrderError("Bạn không phải shipper của đơn này", 403)
    if order.status != OrderStatus.accepted:
        raise OrderError("Chỉ có thể xác nhận giao từ trạng thái 'đã nhận'", 400)

    if adjusted_gold is not None:
        original = float(order.gold_reward)
        if adjusted_gold < 2:
            raise OrderError("Gold tối thiểu là 2", 400)
        if adjusted_gold > original:
            raise OrderError("Không thể tăng gold khi xác nhận giao", 400)
        if adjusted_gold < original:
            diff = original - adjusted_gold
            try:
                await partial_refund_on_delivery(db, order.creator_id, order.id, diff)
            except GoldError as e:
                raise OrderError(e.detail, e.status_code)
            order.gold_reward = adjusted_gold

    now = datetime.now(timezone.utc)
    order.status = OrderStatus.delivering
    order.delivering_at = now
    await db.flush()

    await publish_event("order_delivering", {"order_id": str(order.id)})
    await _push(db, order.creator_id, "Shipper đã báo giao hàng", "Xác nhận đã nhận được hàng để hoàn tất đơn", order.id)
    return await _get_order_or_404(db, order.id)


# ─── SHIPPER: REDUCE GOLD DURING DELIVERY ────────────────────

async def shipper_reduce_gold(
    db: AsyncSession,
    shipper: User,
    order_id: uuid.UUID,
    new_gold: float,
) -> Order:
    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.shipper_id != shipper.id:
        raise OrderError("Bạn không phải shipper của đơn này", 403)
    if order.status != OrderStatus.delivering:
        raise OrderError("Chỉ có thể giảm gold khi đơn đang ở trạng thái 'đang giao'", 400)

    current = float(order.gold_reward)
    if new_gold >= current:
        raise OrderError("Chỉ được giảm gold, không được tăng", 400)

    diff = current - new_gold
    try:
        await reduce_gold_in_delivery(db, order.creator_id, order.id, diff, new_gold)
    except GoldError as e:
        raise OrderError(e.detail, e.status_code)

    order.gold_reward = new_gold
    await db.flush()
    return await _get_order_or_404(db, order.id)


# ─── SHIPPER: CANCEL ACCEPTED/DELIVERING ─────────────────────

async def shipper_cancel_order(db: AsyncSession, shipper: User, order_id: uuid.UUID) -> Order:
    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.shipper_id != shipper.id:
        raise OrderError("Bạn không phải shipper của đơn này", 403)
    if order.status not in (OrderStatus.accepted, OrderStatus.delivering):
        raise OrderError("Chỉ có thể huỷ đơn đang ở trạng thái 'đã nhận' hoặc 'đang giao'", 400)

    now = datetime.now(timezone.utc)
    still_valid = order.expires_at > now

    creator_id = order.creator_id
    if still_valid:
        # Reopen the order so another shipper can pick it up
        order.status = OrderStatus.pending
        order.shipper_id = None
        order.accepted_at = None
        order.estimated_minutes = None
        order.estimated_delivery_at = None
        await db.flush()
        await publish_event("order_reopened", {"order_id": str(order.id)})
    else:
        order.status = OrderStatus.cancelled
        order.cancelled_at = now
        # Refund gold back to creator (gold was locked but never paid to shipper)
        await refund_creator_on_shipper_cancel(db, order.creator_id, order.id, float(order.gold_reward))
        await db.flush()
        await publish_event("order_cancelled", {"order_id": str(order.id)})

    await _invalidate_order_cache()
    await _push(db, creator_id, "Shipper đã huỷ đơn", "Đơn của bạn đã được mở lại để shipper khác nhận", order.id)
    return await _get_order_or_404(db, order.id)


# ─── COMPLETE (creator confirms receipt) ─────────────────────

async def complete_order(
    db: AsyncSession,
    user: User,
    order_id: uuid.UUID,
    bonus_gold: float | None = None,
) -> Order:
    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.creator_id != user.id:
        raise OrderError("Chỉ người tạo đơn mới có thể xác nhận hoàn thành", 403)
    if order.status not in (OrderStatus.accepted, OrderStatus.delivering):
        raise OrderError("Chỉ có thể hoàn thành đơn đang ở trạng thái 'đã nhận' hoặc 'đang giao'", 400)

    order.status = OrderStatus.completed
    order.completed_at = datetime.now(timezone.utc)

    # Release locked gold to shipper
    try:
        await reward_shipper(db, order.shipper_id, order.id, float(order.gold_reward))
        if bonus_gold and bonus_gold > 0:
            await bonus_gold_on_completion(db, user.id, order.shipper_id, order.id, bonus_gold)
            order.gold_reward = float(order.gold_reward) + bonus_gold
    except GoldError as e:
        raise OrderError(e.detail, e.status_code)

    shipper_id = order.shipper_id
    await db.flush()
    await publish_event("order_completed", {"order_id": str(order.id)})
    await _push(db, shipper_id, "Đơn hoàn thành!", f"{float(order.gold_reward):.0f} Gold đã được cộng vào tài khoản", order.id)
    return await _get_order_or_404(db, order.id)


# ─── DISPUTE (creator claims non-delivery) ───────────────────

async def dispute_order(db: AsyncSession, user: User, order_id: uuid.UUID) -> Order:
    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.creator_id != user.id:
        raise OrderError("Chỉ người tạo đơn mới có thể báo xung đột", 403)
    if order.status != OrderStatus.delivering:
        raise OrderError("Chỉ có thể báo xung đột khi đơn đang ở trạng thái 'đang giao'", 400)

    order.status = OrderStatus.disputed
    order.completed_at = datetime.now(timezone.utc)

    try:
        await dispute_gold(db, order.creator_id, order.shipper_id, order.id, float(order.gold_reward))
    except GoldError as e:
        raise OrderError(e.detail, e.status_code)

    shipper_id = order.shipper_id
    await db.flush()
    await publish_event("order_disputed", {"order_id": str(order.id)})
    await _push(db, shipper_id, "Xung đột đơn hàng", "Người đặt báo chưa nhận được hàng. Gold được chia đôi.", order.id)
    return await _get_order_or_404(db, order.id)


# ─── CANCEL ─────────────────────────────────────────────────

async def cancel_order(db: AsyncSession, user: User, order_id: uuid.UUID) -> Order:
    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.creator_id != user.id:
        raise OrderError("Chỉ người tạo mới có thể huỷ đơn", 403)

    now = datetime.now(timezone.utc)

    shipper_id: uuid.UUID | None = None

    if order.status == OrderStatus.pending:
        order.status = OrderStatus.cancelled
        order.cancelled_at = now
        await refund_creator(db, order.creator_id, order.id, float(order.gold_reward))

    elif order.status == OrderStatus.accepted:
        # Allow creator to cancel within 10 minutes of acceptance
        if order.accepted_at is None or (now - order.accepted_at).total_seconds() > 600:
            raise OrderError("Chỉ có thể huỷ đơn đã nhận trong vòng 10 phút đầu", 400)
        shipper_id = order.shipper_id
        order.status = OrderStatus.cancelled
        order.cancelled_at = now
        await refund_creator_on_accepted_cancel(db, order.creator_id, order.id, float(order.gold_reward))

    else:
        raise OrderError("Không thể huỷ đơn ở trạng thái hiện tại", 400)

    await db.flush()
    await publish_event("order_cancelled", {"order_id": str(order.id)})
    await _invalidate_order_cache()
    if shipper_id:
        await _push(db, shipper_id, "Đơn hàng bị huỷ", "Người đặt đã huỷ đơn bạn đang nhận. Gold đã được hoàn trả.", order.id)
    return await _get_order_or_404(db, order.id)


# ─── GOLD PROPOSALS ─────────────────────────────────────────────────────────

async def propose_gold(
    db: AsyncSession,
    user: User,
    order_id: uuid.UUID,
    proposed_gold: float,
) -> "GoldProposal":  # type: ignore[name-defined]
    from sqlalchemy.dialects.postgresql import insert as pg_insert
    from app.models.gold_proposal import GoldProposal

    order = await db.scalar(select(Order).where(Order.id == order_id))
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.status != OrderStatus.pending:
        raise OrderError("Chỉ có thể đề nghị trên đơn đang chờ tiếp nhận", 400)
    if order.creator_id == user.id:
        raise OrderError("Không thể đề nghị trên đơn của chính mình", 400)
    if proposed_gold <= float(order.gold_reward):
        raise OrderError(f"Mức đề nghị phải cao hơn {float(order.gold_reward)} Gold", 400)

    stmt = (
        pg_insert(GoldProposal)
        .values(order_id=order_id, proposer_id=user.id, proposed_gold=proposed_gold)
        .on_conflict_do_update(
            constraint="uq_gold_proposal_order_proposer",
            set_={"proposed_gold": proposed_gold, "created_at": datetime.now(timezone.utc)},
        )
        .returning(GoldProposal.id)
    )
    result = await db.execute(stmt)
    proposal_id = result.scalar_one()
    await db.commit()

    proposal = await db.scalar(
        select(GoldProposal)
        .where(GoldProposal.id == proposal_id)
        .options(selectinload(GoldProposal.proposer))
    )

    proposer_name = proposal.proposer.display_name or proposal.proposer.username
    await _push(
        db,
        order.creator_id,
        "Shipper đề nghị tăng Gold!",
        f"{proposer_name} đề nghị tăng lên {proposed_gold:.0f} Gold cho đơn của bạn",
        order.id,
    )

    return proposal


async def list_proposals(
    db: AsyncSession,
    user: User,
    order_id: uuid.UUID,
) -> list["GoldProposal"]:  # type: ignore[name-defined]
    from app.models.gold_proposal import GoldProposal

    order = await db.scalar(select(Order).where(Order.id == order_id))
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.creator_id != user.id:
        raise OrderError("Chỉ người tạo đơn mới xem được đề nghị", 403)

    result = await db.execute(
        select(GoldProposal)
        .where(GoldProposal.order_id == order_id)
        .options(selectinload(GoldProposal.proposer))
        .order_by(GoldProposal.proposed_gold.desc())
    )
    return list(result.scalars().all())


async def accept_gold_proposal(
    db: AsyncSession,
    user: User,
    order_id: uuid.UUID,
    proposal_id: uuid.UUID,
) -> Order:
    from sqlalchemy import delete
    from app.models.gold_proposal import GoldProposal

    order = await db.scalar(
        select(Order).where(Order.id == order_id).with_for_update()
    )
    if not order:
        raise OrderError("Đơn không tồn tại", 404)
    if order.creator_id != user.id:
        raise OrderError("Chỉ người tạo đơn mới chấp nhận được đề nghị", 403)
    if order.status != OrderStatus.pending:
        raise OrderError("Chỉ chấp nhận đề nghị trên đơn đang chờ tiếp nhận", 400)

    proposal = await db.scalar(
        select(GoldProposal).where(
            GoldProposal.id == proposal_id,
            GoldProposal.order_id == order_id,
        )
    )
    if not proposal:
        raise OrderError("Không tìm thấy đề nghị", 404)

    old_gold = float(order.gold_reward)
    new_gold = float(proposal.proposed_gold)
    proposer_id = proposal.proposer_id  # capture before bulk-delete below

    await adjust_gold_for_order_edit(db, user.id, order_id, old_gold, new_gold)
    order.gold_reward = new_gold

    await db.execute(delete(GoldProposal).where(GoldProposal.order_id == order_id))
    await db.flush()
    await _invalidate_order_cache()

    updated_order = await _get_order_or_404(db, order.id)
    await _push(
        db,
        proposer_id,
        "Đề nghị Gold được chấp nhận!",
        f"Người đặt chấp nhận mức {new_gold:.0f} Gold của bạn. Hãy vào nhận đơn ngay!",
        order.id,
    )
    return updated_order
