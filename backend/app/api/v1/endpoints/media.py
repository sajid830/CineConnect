import io
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import StreamingResponse

from app.api.dependencies import get_current_user
from app.models.user import User
from app.schemas.media import MediaUploadUrlRequest, MediaUploadUrlResponse
from app.services.storage import generate_presigned_upload_url, get_internal_s3_client as get_s3_client

router = APIRouter()


@router.post("/upload-url", response_model=MediaUploadUrlResponse)
async def generate_media_upload_url(
    req: MediaUploadUrlRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    """
    Generate an AWS Signature Version 4 (SigV4) presigned upload URL for direct
    client-to-storage media uploads (MinIO / S3).
    Routes to public (cineconnect-public) or private (cineconnect-private) bucket based on purpose.
    Validates MIME type prefix and declared file size.
    """
    try:
        client_host = request.url.hostname
        data = generate_presigned_upload_url(
            file_name=req.file_name,
            content_type=req.content_type,
            user_id=current_user.id,
            file_size_bytes=req.file_size_bytes,
            purpose=req.purpose,
            client_host=client_host,
        )
        return MediaUploadUrlResponse(**data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.put("/upload/{bucket}/{file_key:path}")
async def proxy_media_upload(
    bucket: str,
    file_key: str,
    request: Request,
):
    """Direct streaming upload proxy to MinIO storage for tunnel and remote clients."""
    authorized_buckets = ("cineconnect-public", "cineconnect-private")
    if bucket not in authorized_buckets:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid bucket")

    content_type = request.headers.get("content-type", "application/octet-stream")
    body = await request.body()
    if not body:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty request body")

    s3 = get_s3_client()
    s3.upload_fileobj(
        io.BytesIO(body),
        bucket,
        file_key,
        ExtraArgs={"ContentType": content_type},
    )
    return {"status": "ok", "bucket": bucket, "file_key": file_key}


@router.get("/file/{bucket}/{file_key:path}")
async def proxy_media_download(
    bucket: str,
    file_key: str,
):
    """Direct streaming download proxy from MinIO storage for tunnel and remote clients."""
    authorized_buckets = ("cineconnect-public", "cineconnect-private")
    if bucket not in authorized_buckets:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid bucket")

    s3 = get_s3_client()
    try:
        obj = s3.get_object(Bucket=bucket, Key=file_key)
        return StreamingResponse(
            obj["Body"],
            media_type=obj.get("ContentType", "application/octet-stream"),
        )
    except Exception:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")

