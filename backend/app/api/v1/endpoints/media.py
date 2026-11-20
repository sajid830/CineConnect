from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_current_user
from app.models.user import User
from app.schemas.media import MediaUploadUrlRequest, MediaUploadUrlResponse
from app.services.storage import generate_presigned_upload_url

router = APIRouter()


@router.post("/upload-url", response_model=MediaUploadUrlResponse)
async def generate_media_upload_url(
    req: MediaUploadUrlRequest,
    current_user: User = Depends(get_current_user),
):
    """
    Generate an AWS Signature Version 4 (SigV4) presigned upload URL for direct
    client-to-storage media uploads (MinIO / S3).
    Routes to public (cineconnect-public) or private (cineconnect-private) bucket based on purpose.
    Validates MIME type prefix and declared file size.
    """
    try:
        data = generate_presigned_upload_url(
            file_name=req.file_name,
            content_type=req.content_type,
            user_id=current_user.id,
            file_size_bytes=req.file_size_bytes,
            purpose=req.purpose,
        )
        return MediaUploadUrlResponse(**data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
