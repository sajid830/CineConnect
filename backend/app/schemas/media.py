from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field


class MediaUploadUrlRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    file_name: str = Field(..., json_schema_extra={"example": "audition_reel.mp4"})
    content_type: str = Field(..., json_schema_extra={"example": "video/mp4"})
    file_size_bytes: Optional[int] = Field(None, json_schema_extra={"example": 52428800})
    purpose: Literal["public", "private"] = Field(
        "public",
        description="Target bucket purpose: 'public' (cineconnect-public) or 'private' (cineconnect-private)",
        json_schema_extra={"example": "public"},
    )


class MediaUploadUrlResponse(BaseModel):
    upload_url: str
    file_key: str
    public_url: str
    bucket: str
    purpose: str
    expires_in_seconds: int = 3600
