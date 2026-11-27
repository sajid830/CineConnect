from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, model_validator
from app.schemas.user import TalentSummaryResponse


class ApplicationBase(BaseModel):
    cover_letter: Optional[str] = Field(None, json_schema_extra={"example": "I am deeply passionate about this role and have attached my showreel."})
    resume_url: Optional[str] = Field(None, json_schema_extra={"example": "https://cdn.cineconnect.com/resumes/actor.pdf"})
    reel_url: Optional[str] = Field(None, json_schema_extra={"example": "https://vimeo.com/123456789"})


class ApplicationCreate(ApplicationBase):
    opportunity_id: Optional[UUID] = Field(None, json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})
    project_id: Optional[UUID] = Field(None, json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})

    @model_validator(mode="after")
    def validate_target(self) -> "ApplicationCreate":
        if not self.opportunity_id and not self.project_id:
            raise ValueError("Either opportunity_id or project_id must be provided.")
        return self


class ApplicationUpdate(ApplicationBase):
    pass


class ApplicationPatch(ApplicationBase):
    pass


class ApplicationStatusUpdate(BaseModel):
    status: str = Field(..., json_schema_extra={"example": "shortlisted"})


class ApplicationResponse(ApplicationBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    opportunity_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    talent_id: UUID
    status: str
    target_type: Optional[str] = None  # "project" or "job"
    project_title: Optional[str] = None
    opportunity_title: Optional[str] = None
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
