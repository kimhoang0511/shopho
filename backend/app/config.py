from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # DB
    database_url: str
    database_pool_size: int = 10
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

    # Admin
    admin_username: str = "admin"
    admin_password: str = "Admin@2026"


@lru_cache
def get_settings() -> Settings:
    return Settings()
