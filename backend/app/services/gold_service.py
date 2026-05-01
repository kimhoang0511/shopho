"""
All gold mutations go through here.
Every operation is wrapped in a DB transaction and writes to gold_ledger
before modifying users.gold_balance – ensuring a complete audit trail.
"""
import uuid
from decimal import Decimal

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.gold import GoldLedger, GoldTxType
from app.models.user import User


class GoldError(Exception):
    def __init__(self, detail: str, status_code: int = 400):
        self.detail = detail
        self.status_code = status_code


async def _record_and_update(
    db: AsyncSession,
    user_id: uuid.UUID,
    amount: Decimal,          # positive = credit, negative = debit
    tx_type: GoldTxType,
    order_id: uuid.UUID | None = None,
    description: str | None = None,
    idempotency_key: str | None = None,
) -> float:
    """
    Atomically debit/credit a user's gold balance.
    Returns the new balance.
    Raises GoldError on insufficient funds or duplicate idempotency key.
    """
    # Fast-path idempotency check (no lock – avoids unnecessary row lock on cache hits).
    if idempotency_key:
        existing = await db.scalar(
            select(GoldLedger).where(GoldLedger.idempotency_key == idempotency_key)
        )
        if existing:
            return float(existing.balance_after)

    # Lock the user row so concurrent deductions are serialised.
    result = await db.execute(
        select(User)
        .where(User.id == user_id)
        .with_for_update()
    )
    user = result.scalar_one_or_none()
    if not user:
        raise GoldError("Người dùng không tồn tại", 404)

    # Re-check idempotency inside the lock: handles the case where two concurrent
    # requests with the same key both passed the fast-path check above (because
    # neither had committed yet).  After acquiring the lock the first request's
    # GoldLedger entry is now visible, so the second can return gracefully instead
    # of hitting a UNIQUE-constraint error.
    if idempotency_key:
        existing = await db.scalar(
            select(GoldLedger).where(GoldLedger.idempotency_key == idempotency_key)
        )
        if existing:
            return float(existing.balance_after)

    new_balance = Decimal(str(user.gold_balance)) + amount
    if new_balance < 0:
        raise GoldError(
            f"Số dư gold không đủ (hiện tại: {user.gold_balance}, cần: {abs(float(amount))})",
            402,
        )

    user.gold_balance = new_balance
    db.add(GoldLedger(
        user_id=user_id,
        order_id=order_id,
        tx_type=tx_type,
        amount=float(amount),
        balance_after=float(new_balance),
        description=description,
        idempotency_key=idempotency_key,
    ))
    return float(new_balance)


async def lock_gold_for_order(
    db: AsyncSession,
    user_id: uuid.UUID,
    order_id: uuid.UUID,
    amount: float,
) -> float:
    """Deduct gold from creator when they create an order."""
    return await _record_and_update(
        db, user_id, Decimal(str(-amount)),
        GoldTxType.order_lock, order_id=order_id,
        description=f"Khoá gold cho đơn {order_id}",
        idempotency_key=f"lock:{order_id}",
    )


async def reward_shipper(
    db: AsyncSession,
    shipper_id: uuid.UUID,
    order_id: uuid.UUID,
    amount: float,
) -> float:
    """Credit gold to shipper after accepting an order."""
    return await _record_and_update(
        db, shipper_id, Decimal(str(amount)),
        GoldTxType.order_reward, order_id=order_id,
        description=f"Nhận gold từ đơn {order_id}",
        idempotency_key=f"reward:{order_id}",
    )


async def refund_creator(
    db: AsyncSession,
    creator_id: uuid.UUID,
    order_id: uuid.UUID,
    amount: float,
) -> float:
    """Refund gold to creator when order is expired or cancelled (before accept)."""
    return await _record_and_update(
        db, creator_id, Decimal(str(amount)),
        GoldTxType.order_refund, order_id=order_id,
        description=f"Hoàn gold đơn {order_id}",
        idempotency_key=f"refund:{order_id}",
    )


async def partial_refund_on_delivery(
    db: AsyncSession,
    creator_id: uuid.UUID,
    order_id: uuid.UUID,
    amount: float,
) -> float:
    """Refund the gold difference to creator when shipper voluntarily reduces the reward."""
    return await _record_and_update(
        db, creator_id, Decimal(str(amount)),
        GoldTxType.order_refund, order_id=order_id,
        description=f"Hoàn bớt gold do shipper giảm thưởng đơn {order_id}",
        idempotency_key=f"delivery_partial_refund:{order_id}",
    )


async def refund_creator_on_accepted_cancel(
    db: AsyncSession,
    creator_id: uuid.UUID,
    order_id: uuid.UUID,
    amount: float,
) -> float:
    """Refund gold to creator when creator cancels an accepted order within the grace period."""
    return await _record_and_update(
        db, creator_id, Decimal(str(amount)),
        GoldTxType.order_refund, order_id=order_id,
        description=f"Hoàn gold do huỷ đơn đã nhận {order_id}",
        idempotency_key=f"creator_cancel_accepted:{order_id}",
    )


async def refund_creator_on_shipper_cancel(
    db: AsyncSession,
    creator_id: uuid.UUID,
    order_id: uuid.UUID,
    amount: float,
) -> float:
    """Refund gold to creator when shipper cancels an accepted/delivering order."""
    return await _record_and_update(
        db, creator_id, Decimal(str(amount)),
        GoldTxType.order_refund, order_id=order_id,
        description=f"Hoàn gold do shipper huỷ đơn {order_id}",
        idempotency_key=f"shipper_cancel_refund:{order_id}",
    )


async def adjust_gold_for_order_edit(
    db: AsyncSession,
    creator_id: uuid.UUID,
    order_id: uuid.UUID,
    old_amount: float,
    new_amount: float,
) -> None:
    """Adjust locked gold when creator edits the reward on a pending order."""
    diff = new_amount - old_amount
    if diff == 0:
        return
    # Encode new_amount in cents to avoid float key collisions, e.g. "edit_lock:xxx:12000"
    new_cents = int(round(new_amount * 100))
    if diff > 0:
        await _record_and_update(
            db, creator_id, Decimal(str(-diff)),
            GoldTxType.order_lock, order_id=order_id,
            description=f"Khoá thêm gold sửa đơn {order_id}",
            idempotency_key=f"edit_lock:{order_id}:{new_cents}",
        )
    else:
        await _record_and_update(
            db, creator_id, Decimal(str(-diff)),  # -diff > 0 → credit
            GoldTxType.order_refund, order_id=order_id,
            description=f"Hoàn bớt gold sửa đơn {order_id}",
            idempotency_key=f"edit_refund:{order_id}:{new_cents}",
        )


async def dispute_gold(
    db: AsyncSession,
    creator_id: uuid.UUID,
    shipper_id: uuid.UUID,
    order_id: uuid.UUID,
    gold_reward: float,
) -> None:
    """On dispute: shipper gets 50%, creator is refunded the rest (handles odd amounts)."""
    total = Decimal(str(gold_reward))
    shipper_share = (total / 2).quantize(Decimal("0.01"))
    creator_refund = total - shipper_share

    # Always acquire user row locks in UUID order to prevent deadlocks.
    # Two concurrent transactions touching the same pair of users (e.g. user A
    # is shipper on order-1 and creator on order-2) would deadlock if each locks
    # them in opposite order.  Sorting by UUID breaks the cycle.
    if shipper_id <= creator_id:
        await _record_and_update(
            db, shipper_id, shipper_share,
            GoldTxType.order_reward, order_id=order_id,
            description=f"Nhận 50% gold (xung đột) từ đơn {order_id}",
            idempotency_key=f"dispute_reward:{order_id}",
        )
        await _record_and_update(
            db, creator_id, creator_refund,
            GoldTxType.order_refund, order_id=order_id,
            description=f"Hoàn gold (xung đột) đơn {order_id}",
            idempotency_key=f"dispute_refund:{order_id}",
        )
    else:
        await _record_and_update(
            db, creator_id, creator_refund,
            GoldTxType.order_refund, order_id=order_id,
            description=f"Hoàn gold (xung đột) đơn {order_id}",
            idempotency_key=f"dispute_refund:{order_id}",
        )
        await _record_and_update(
            db, shipper_id, shipper_share,
            GoldTxType.order_reward, order_id=order_id,
            description=f"Nhận 50% gold (xung đột) từ đơn {order_id}",
            idempotency_key=f"dispute_reward:{order_id}",
        )


async def reduce_gold_in_delivery(
    db: AsyncSession,
    creator_id: uuid.UUID,
    order_id: uuid.UUID,
    diff: float,
    new_gold: float,
) -> float:
    """Refund the gold difference to creator when shipper reduces reward while in delivering state."""
    new_cents = int(round(new_gold * 100))
    return await _record_and_update(
        db, creator_id, Decimal(str(diff)),
        GoldTxType.order_refund, order_id=order_id,
        description=f"Shipper giảm gold khi đang giao đơn {order_id}",
        idempotency_key=f"reduce_delivering:{order_id}:{new_cents}",
    )


async def bonus_gold_on_completion(
    db: AsyncSession,
    creator_id: uuid.UUID,
    shipper_id: uuid.UUID,
    order_id: uuid.UUID,
    bonus: float,
) -> None:
    """Deduct bonus gold from creator and credit it to shipper at order completion."""
    # Lock in UUID order (same deadlock-prevention rule as dispute_gold).
    if creator_id <= shipper_id:
        await _record_and_update(
            db, creator_id, Decimal(str(-bonus)),
            GoldTxType.order_lock, order_id=order_id,
            description=f"Thưởng thêm cho shipper đơn {order_id}",
            idempotency_key=f"bonus_complete_deduct:{order_id}",
        )
        await _record_and_update(
            db, shipper_id, Decimal(str(bonus)),
            GoldTxType.order_reward, order_id=order_id,
            description=f"Nhận thưởng thêm từ đơn {order_id}",
            idempotency_key=f"bonus_complete_reward:{order_id}",
        )
    else:
        await _record_and_update(
            db, shipper_id, Decimal(str(bonus)),
            GoldTxType.order_reward, order_id=order_id,
            description=f"Nhận thưởng thêm từ đơn {order_id}",
            idempotency_key=f"bonus_complete_reward:{order_id}",
        )
        await _record_and_update(
            db, creator_id, Decimal(str(-bonus)),
            GoldTxType.order_lock, order_id=order_id,
            description=f"Thưởng thêm cho shipper đơn {order_id}",
            idempotency_key=f"bonus_complete_deduct:{order_id}",
        )


async def top_up(
    db: AsyncSession,
    user_id: uuid.UUID,
    amount: float,
    payment_tx_id: str,  # external payment transaction ID – required for idempotency
) -> float:
    return await _record_and_update(
        db, user_id, Decimal(str(amount)),
        GoldTxType.top_up,
        description="Nạp gold",
        idempotency_key=f"topup:{payment_tx_id}",
    )
