from fastapi import APIRouter

from app.config import get_settings

router = APIRouter(prefix="/app", tags=["app"])


@router.get("/config")
def get_app_config():
    s = get_settings()
    return {
        "zalo_contact": s.zalo_contact,
        "app_min_version": s.app_min_version,
        "app_latest_version": s.app_latest_version,
        "android_store_url": s.android_store_url,
        "ios_store_url": s.ios_store_url,
    }
