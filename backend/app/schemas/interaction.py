from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class InteractionCreate(BaseModel):
    post_id: UUID = Field(..., json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})
    type: str = Field("like", json_schema_extra={"example": "like"})  # 'like', 'comment'
    comment: Optional[str] = Field(None, json_schema_extra={"example": "Stunning lighting! Which lens did you use?"})


class InteractionPatch(BaseModel):
    comment: Optional[str] = None


class InteractionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    post_id: UUID
    user_id: UUID
    type: str
    comment: Optional[str]
    created_at: datetime
