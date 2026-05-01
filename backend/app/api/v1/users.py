from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.deps import current_user
from app.database import get_db
from app.models.apartment import Apartment
from app.models.gold import GoldLedger
from app.models.user import ShipperAlert, User
from app.schemas.apartment import ApartmentOut
from app.schemas.user import GoldHistoryItem, UserProfile, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserProfile)
async def get_me(user: User = Depends(current_user)):
    return user


@router.patch("/me", response_model=UserProfile)
async def update_me(
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(user, field, value)
    db.add(user)
    return user


@router.get("/apartments", response_model=list[ApartmentOut])
async def list_apartments_for_user(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(current_user),
):
    result = await db.execute(
        select(Apartment).options(selectinload(Apartment.buildings)).order_by(Apartment.name)
    )
    return list(result.scalars().all())


@router.get("/me/gold/history", response_model=list[GoldHistoryItem])
async def gold_history(
    limit: int = Query(30, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    result = await db.execute(
        select(GoldLedger)
        .where(GoldLedger.user_id == user.id)
        .order_by(GoldLedger.created_at.desc())
        .limit(limit).offset(offset)
    )
    return list(result.scalars().all())


@router.post("/me/device-token", status_code=204)
async def register_device_token(
    body: dict,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    from app.models.user import DeviceToken
    from sqlalchemy.dialects.postgresql import insert as pg_insert
    token = body.get("token", "").strip()
    platform = body.get("platform", "android").strip()
    if not token:
        return
    stmt = (
        pg_insert(DeviceToken)
        .values(user_id=user.id, token=token, platform=platform)
        .on_conflict_do_nothing()
    )
    await db.execute(stmt)
    await db.commit()


# ─── Browse-alert (notification when new order matches filter) ─

class _BrowseAlertBody(BaseModel):
    enabled: bool
    apartment_ids: list[str] = []
    building_keys: list[str] = []
    floors: list[int] = []


@router.get("/me/browse-alert")
async def get_browse_alert(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    alert = await db.get(ShipperAlert, user.id)
    if alert is None:
        return {"enabled": False, "apartment_ids": [], "building_keys": [], "floors": []}
    return {
        "enabled": alert.enabled,
        "apartment_ids": alert.apartment_ids or [],
        "building_keys": alert.building_keys or [],
        "floors": alert.floors or [],
    }


@router.put("/me/browse-alert", status_code=204)
async def update_browse_alert(
    body: _BrowseAlertBody,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    from sqlalchemy.dialects.postgresql import insert as pg_insert
    stmt = (
        pg_insert(ShipperAlert)
        .values(
            user_id=user.id,
            enabled=body.enabled,
            apartment_ids=body.apartment_ids,
            building_keys=body.building_keys,
            floors=body.floors,
        )
        .on_conflict_do_update(
            index_elements=["user_id"],
            set_={
                "enabled": body.enabled,
                "apartment_ids": body.apartment_ids,
                "building_keys": body.building_keys,
                "floors": body.floors,
                "updated_at": text("NOW()"),
            },
        )
    )
    await db.execute(stmt)
