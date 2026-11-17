from typing import Optional
from pydantic import BaseModel, Field


class MediaUploadUrlRequest(BaseModel):
    file_name: str = Field(..., json_schema_extra={"example": "audition_reel.mp4"})
    content_type: str = Field(..., json_schema_extra={"example": "video/mp4"})
    file_size_bytes: Optional[int] = Field(None, json_schema_extra={"example": 52428800})


class MediaUploadUrlResponse(BaseModel):
    upload_url: str
    file_key: str
    public_url: str
    expires_in_seconds: int = 3600
