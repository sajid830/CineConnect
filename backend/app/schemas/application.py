from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class ApplicationBase(BaseModel):
    cover_letter: Optional[str] = Field(None, json_schema_extra={"example": "I am deeply passionate about this role and have attached my showreel."})
    resume_url: Optional[str] = Field(None, json_schema_extra={"example": "https://cdn.cineconnect.com/resumes/actor.pdf"})
    reel_url: Optional[str] = Field(None, json_schema_extra={"example": "https://vimeo.com/123456789"})


class ApplicationCreate(ApplicationBase):
    opportunity_id: UUID = Field(..., json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})


class ApplicationUpdate(ApplicationBase):
    pass


class ApplicationPatch(ApplicationBase):
    pass


class ApplicationStatusUpdate(BaseModel):
    status: str = Field(..., json_schema_extra={"example": "shortlisted"})


class ApplicationResponse(ApplicationBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    opportunity_id: UUID
    talent_id: UUID
    status: str
    created_at: datetime
    updated_at: datetime
