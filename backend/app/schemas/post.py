from datetime import datetime
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.user import TalentSummaryResponse


class PostBase(BaseModel):
    caption: Optional[str] = Field("", json_schema_extra={"example": "Just wrapped up Day 14 on our indie thriller feature film!"})
    media_url: Optional[str] = Field(None, json_schema_extra={"example": "https://cdn.cineconnect.com/posts/bts-day14.jpg"})
    video_slate_title: Optional[str] = Field(None, json_schema_extra={"example": "SCENE 84A / TAKE 3 [ANAMORPHIC MASTER 2.39:1]"})
    smpte_timecode: Optional[str] = Field(None, json_schema_extra={"example": "TC 01:24:19:18"})
    aspect_ratio: Optional[str] = Field("2.39:1", json_schema_extra={"example": "2.39:1"})
    tags: Optional[List[str]] = Field(None, json_schema_extra={"example": ["Cinematography", "Lighting"]})


class PostCreate(PostBase):
    pass


class PostUpdate(PostBase):
    pass


class PostResponse(PostBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    author_name: Optional[str] = None
    author_craft: Optional[str] = None
    author_avatar: Optional[str] = None
    guild_badge: Optional[str] = None
    likes_count: int = 0
    comments_count: int = 0
    is_liked: bool = False
    like_interaction_id: Optional[UUID] = None
    is_bookmarked: bool = False
    author: Optional[TalentSummaryResponse] = None
    created_at: datetime
    updated_at: datetime
