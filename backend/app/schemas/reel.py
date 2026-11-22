from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.user import TalentSummaryResponse


class ReelBase(BaseModel):
    title: str = Field(..., json_schema_extra={"example": "ARRI Alexa 35 Anamorphic Reel"})
    caption: Optional[str] = Field(None, json_schema_extra={"example": "Cooke Anamorphic /i flare test"})
    media_url: str = Field(..., json_schema_extra={"example": "https://minio.cineconnect.local/media/reel.mp4"})
    thumbnail_url: Optional[str] = Field(None, json_schema_extra={"example": "https://minio.cineconnect.local/media/thumb.jpg"})
    audio_track: Optional[str] = Field(None, json_schema_extra={"example": "Hans Zimmer - Dune Suite"})
    smpte_timecode: Optional[str] = Field(None, json_schema_extra={"example": "00:01:14:18"})
    craft_specialty: Optional[str] = Field(None, json_schema_extra={"example": "Anamorphic 2.39:1 Flare & Shadow"})
    reel_type: Optional[str] = Field("Cinematography Showreel", json_schema_extra={"example": "Cinematography Showreel"})


class ReelCreate(ReelBase):
    pass


class ReelResponse(ReelBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    creator_name: Optional[str] = None
    creator_craft: Optional[str] = None
    creator_avatar: Optional[str] = None
    playback_url: Optional[str] = None
    likes_count: int = 0
    comments_count: int = 0
    is_liked: bool = False
    is_bookmarked: bool = False
    creator: Optional[TalentSummaryResponse] = None
    created_at: datetime
    updated_at: datetime
