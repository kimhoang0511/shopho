from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # DB
    database_url: str
    database_pool_size: int = 10

    @property
    def async_database_url(self) -> str:
        return self.database_url.replace("postgresql://", "postgresql+asyncpg://", 1)
    database_max_overflow: int = 20

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # JWT
    secret_key: str
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    # Cloudflare R2 (S3-compatible storage)
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket_name: str = "order-food-images"
    r2_public_url: str = ""

    # App
    app_env: str = "development"
    cors_origins: list[str] = ["http://localhost:3000"]

    # LiveKit
    livekit_url: str = ""
    livekit_api_key: str = ""
    livekit_api_secret: str = ""

    # APNs VoIP Push (iOS)
    apns_key_id: str = ""
    apns_team_id: str = ""
    apns_bundle_id: str = ""
    apns_key_path: str = "backend/apns-key.p8"

    # Admin
    admin_username: str = "admin"
    admin_password: str = "Admin@2026"

    # Contact
    zalo_contact: str = ""

    # Version gate
    app_min_version: str = "1.0.0"      # below this → force update
    app_latest_version: str = "1.0.0"   # below this → soft update suggestion
    android_store_url: str = ""
    ios_store_url: str = ""

    # VietQR / Payment top-up
    vietqr_bank_id: str = ""          # e.g. "MB" or "VCB"
    vietqr_account_number: str = ""   # bank account number
    payment_webhook_secret: str = ""  # secret token to verify webhook calls


@lru_cache
def get_settings() -> Settings:
    return Settings()
