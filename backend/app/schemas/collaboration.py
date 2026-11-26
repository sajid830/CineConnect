from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.user import TalentSummaryResponse


class CollaborationCreate(BaseModel):
    project_id: UUID = Field(..., json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})
    talent_id: UUID = Field(..., json_schema_extra={"example": "234e5678-e89b-12d3-a456-426614174000"})
    role: Optional[str] = Field(None, json_schema_extra={"example": "Lead Cinematographer"})


class CollaborationStatusUpdate(BaseModel):
    status: str = Field(..., json_schema_extra={"example": "accepted"})  # accepted, rejected, completed, cancelled


class CollaborationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    project_id: UUID
    talent_id: UUID
    role: Optional[str] = None
    status: str
    invited_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: datetime
    talent: Optional[TalentSummaryResponse] = None
