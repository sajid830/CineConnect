from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.user import TalentSummaryResponse


class InteractionCreate(BaseModel):
    post_id: UUID = Field(..., json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})
    type: str = Field("like", json_schema_extra={"example": "like"})  # 'like', 'comment'
    comment: Optional[str] = Field(None, json_schema_extra={"example": "Stunning lighting! Which lens did you use?"})
    timecode: Optional[str] = Field(None, json_schema_extra={"example": "00:01:24:19"})


class InteractionPatch(BaseModel):
    comment: Optional[str] = None
    timecode: Optional[str] = None


class InteractionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    post_id: UUID
    user_id: UUID
    type: str
    comment: Optional[str]
    timecode: Optional[str] = None
    user: Optional[TalentSummaryResponse] = None
    created_at: datetime
