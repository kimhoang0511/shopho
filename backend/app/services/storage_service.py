"""MinIO image upload service."""
import uuid

from fastapi import UploadFile
from minio import Minio
from minio.error import S3Error

from app.config import get_settings

settings = get_settings()

_client: Minio | None = None


def _get_client() -> Minio:
    global _client
    if _client is None:
        _client = Minio(
            settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_use_ssl,
        )
        # Ensure bucket exists
        if not _client.bucket_exists(settings.minio_bucket):
            _client.make_bucket(settings.minio_bucket)
            # Set public read policy
            import json
            policy = {
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{settings.minio_bucket}/*"],
                }],
            }
            _client.set_bucket_policy(settings.minio_bucket, json.dumps(policy))
    return _client


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_SIZE_MB = 10


async def upload_image(file: UploadFile) -> tuple[str, str]:
    """Upload image to MinIO. Returns (storage_key, public_url)."""
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise ValueError(f"Định dạng ảnh không hợp lệ: {file.content_type}")

    contents = await file.read()
    if len(contents) > MAX_SIZE_MB * 1024 * 1024:
        raise ValueError(f"Ảnh không được vượt quá {MAX_SIZE_MB}MB")

    ext = file.filename.rsplit(".", 1)[-1].lower() if file.filename else "jpg"
    key = f"orders/{uuid.uuid4()}.{ext}"

    import io
    client = _get_client()
    client.put_object(
        settings.minio_bucket,
        key,
        io.BytesIO(contents),
        length=len(contents),
        content_type=file.content_type,
    )

    protocol = "https" if settings.minio_use_ssl else "http"
    public_url = f"{protocol}://{settings.minio_endpoint}/{settings.minio_bucket}/{key}"
    return key, public_url
