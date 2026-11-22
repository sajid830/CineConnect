from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.user import TalentSummaryResponse


class StoryBase(BaseModel):
    media_url: str = Field(..., json_schema_extra={"example": "https://minio.cineconnect.local/media/story.jpg"})
    caption: Optional[str] = Field(None, json_schema_extra={"example": "Night sequence lighting test"})
    location: Optional[str] = Field(None, json_schema_extra={"example": "Ramoji Film City, Stage 12"})
    craft_badge: Optional[str] = Field(None, json_schema_extra={"example": "Cinematographer (ISC)"})


class StoryCreate(StoryBase):
    pass


class StoryResponse(StoryBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    creator_name: Optional[str] = None
    initials: Optional[str] = None
    time_ago: Optional[str] = None
    has_unseen: bool = True
    playback_url: Optional[str] = None
    creator: Optional[TalentSummaryResponse] = None
    created_at: datetime
    expires_at: datetime
