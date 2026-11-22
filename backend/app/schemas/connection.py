from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.user import TalentSummaryResponse


class ConnectionCreate(BaseModel):
    receiver_id: UUID = Field(..., json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})


class ConnectionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    sender_id: UUID
    receiver_id: UUID
    status: str
    sender: Optional[TalentSummaryResponse] = None
    receiver: Optional[TalentSummaryResponse] = None
    created_at: datetime
    updated_at: datetime
