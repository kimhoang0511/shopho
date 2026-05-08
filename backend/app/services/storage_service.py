"""Cloudflare R2 image upload service (S3-compatible via boto3)."""
import io
import uuid

import boto3
from botocore.config import Config
from fastapi import UploadFile

from app.config import get_settings

settings = get_settings()

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = boto3.client(
            "s3",
            endpoint_url=f"https://{settings.r2_account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            region_name="auto",
            config=Config(signature_version="s3v4"),
        )
    return _client


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_SIZE_MB = 3


async def upload_image(file: UploadFile, prefix: str = "orders") -> tuple[str, str]:
    """Upload image to Cloudflare R2. Returns (storage_key, public_url)."""
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise ValueError(f"Định dạng ảnh không hợp lệ: {file.content_type}")

    contents = await file.read()
    if len(contents) > MAX_SIZE_MB * 1024 * 1024:
        raise ValueError(f"Ảnh không được vượt quá {MAX_SIZE_MB}MB")

    ext = file.filename.rsplit(".", 1)[-1].lower() if file.filename else "jpg"
    key = f"{prefix}/{uuid.uuid4()}.{ext}"

    _get_client().put_object(
        Bucket=settings.r2_bucket_name,
        Key=key,
        Body=io.BytesIO(contents),
        ContentType=file.content_type,
        CacheControl="public, max-age=31536000",
    )

    public_url = f"{settings.r2_public_url.rstrip('/')}/{key}"
    return key, public_url
