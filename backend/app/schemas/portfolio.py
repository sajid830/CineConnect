from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class PortfolioMediaBase(BaseModel):
    title: str = Field(..., json_schema_extra={"example": "Main Acting Showreel 2026"})
    description: Optional[str] = Field(None, json_schema_extra={"example": "Compilation of dramatic scenes from indie features."})
    media_type: str = Field("video", json_schema_extra={"example": "video"})  # video, image, audio, document
    media_url: str = Field(..., json_schema_extra={"example": "https://cdn.cineconnect.com/media/reel.mp4"})
    thumbnail_url: Optional[str] = Field(None, json_schema_extra={"example": "https://cdn.cineconnect.com/media/thumb.jpg"})


class PortfolioMediaCreate(PortfolioMediaBase):
    pass


class PortfolioMediaUpdate(PortfolioMediaBase):
    pass


class PortfolioMediaResponse(PortfolioMediaBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    created_at: datetime
