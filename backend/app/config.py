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

    # MinIO
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "shopho-images"
    minio_use_ssl: bool = False

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


@lru_cache
def get_settings() -> Settings:
    return Settings()
