from datetime import datetime
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class MessageCreate(BaseModel):
    recipient_id: UUID = Field(..., json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})
    body: str = Field(..., json_schema_extra={"example": "Hello! We loved your audition tape and would like to invite you for a chemistry read."})


class MessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    sender_id: UUID
    recipient_id: UUID
    body: str
    is_read: bool
    created_at: datetime


class ConversationSummary(BaseModel):
    user_id: UUID
    full_name: Optional[str]
    last_message: Optional[str]
    last_message_at: Optional[datetime]
    unread_count: int


class UnreadCountResponse(BaseModel):
    unread_count: int
