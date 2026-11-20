from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.user import TalentSummaryResponse


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
    applied_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    talent: Optional[TalentSummaryResponse] = None


class ApplicationDownloadUrlResponse(BaseModel):
    """Temporary authorized presigned download URL for private application documents."""
    download_url: str = Field(..., description="Temporary presigned GET download URL signed with AWS SigV4")
    file_key: str = Field(..., description="Normalized storage object key")
    file_type: str = Field(..., description="Document type: 'resume' or 'reel'")
    expires_in_seconds: int = Field(3600, description="Time until presigned download URL expires")
