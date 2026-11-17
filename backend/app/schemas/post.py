from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class PostBase(BaseModel):
    caption: str = Field(..., json_schema_extra={"example": "Just wrapped up Day 14 on our indie thriller feature film!"})
    media_url: Optional[str] = Field(None, json_schema_extra={"example": "https://cdn.cineconnect.com/posts/bts-day14.jpg"})


class PostCreate(PostBase):
    pass


class PostUpdate(PostBase):
    pass


class PostResponse(PostBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime
