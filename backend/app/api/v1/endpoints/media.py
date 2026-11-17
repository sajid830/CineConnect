import uuid
import hmac
import hashlib
import time
from urllib.parse import urlencode
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import settings
from app.api.dependencies import get_current_user
from app.models.user import User
from app.schemas.media import MediaUploadUrlRequest, MediaUploadUrlResponse

router = APIRouter()

ALLOWED_MIME_PREFIXES = ("image/", "video/", "audio/", "application/pdf")
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB


@router.post("/upload-url", response_model=MediaUploadUrlResponse)
async def generate_media_upload_url(
    req: MediaUploadUrlRequest,
    current_user: User = Depends(get_current_user),
):
    """
    Generate a presigned upload URL for direct client-to-storage media uploads (MinIO / S3).
    Validates MIME type and file size.
    """
    # 1. MIME type validation
    if not any(req.content_type.startswith(prefix) for prefix in ALLOWED_MIME_PREFIXES):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Content type '{req.content_type}' is not permitted. Allowed: images, videos, audio, and PDF documents.",
        )

    # 2. File size validation (if provided)
    if req.file_size_bytes is not None and req.file_size_bytes > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File size exceeds maximum allowed limit of {MAX_FILE_SIZE // (1024 * 1024)} MB.",
        )

    # 3. Generate secure file key
    clean_name = req.file_name.replace(" ", "_")
    file_uuid = uuid.uuid4()
    file_key = f"media/{current_user.id}/{file_uuid}/{clean_name}"
    expires_in = 3600

    # 4. Construct S3/MinIO compatible presigned PUT URL
    protocol = "https" if settings.MINIO_SECURE else "http"
    base_endpoint = f"{protocol}://{settings.MINIO_ENDPOINT}/{settings.MINIO_BUCKET}/{file_key}"
    
    expires_at = int(time.time()) + expires_in
    string_to_sign = f"PUT\n\n{req.content_type}\n{expires_at}\n/{settings.MINIO_BUCKET}/{file_key}"
    signature = hmac.new(
        settings.MINIO_SECRET_KEY.encode(),
        string_to_sign.encode(),
        hashlib.sha1
    ).hexdigest()

    params = {
        "AWSAccessKeyId": settings.MINIO_ACCESS_KEY,
        "Signature": signature,
        "Expires": expires_at,
    }
    upload_url = f"{base_endpoint}?{urlencode(params)}"
    public_url = f"{protocol}://{settings.MINIO_ENDPOINT}/{settings.MINIO_BUCKET}/{file_key}"

    return MediaUploadUrlResponse(
        upload_url=upload_url,
        file_key=file_key,
        public_url=public_url,
        expires_in_seconds=expires_in,
    )
