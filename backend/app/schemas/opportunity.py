from datetime import datetime, date
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class OpportunityBase(BaseModel):
    title: str = Field(..., json_schema_extra={"example": "Actor"})
    role_type: Optional[str] = Field(None, json_schema_extra={"example": "Actor"})
    purpose: Optional[str] = Field(None, json_schema_extra={"example": "Movie"})
    required_members: Optional[int] = Field(1, ge=1, json_schema_extra={"example": 1})
    work_start_date: Optional[date] = Field(None, json_schema_extra={"example": "2026-12-15"})
    experience: Optional[str] = Field(None, json_schema_extra={"example": "2 years"})
    requirements: Optional[str] = Field(None, json_schema_extra={"example": "Fluent in Hindi, martial arts background preferred."})
    location: Optional[str] = Field(None, json_schema_extra={"example": "Mumbai / Goa"})
    compensation: Optional[str] = Field(None, json_schema_extra={"example": "Competitive / SAG-AFTRA Scale"})
    deadline: Optional[date] = Field(None, json_schema_extra={"example": "2026-12-15"})
    status: Optional[str] = Field("open", json_schema_extra={"example": "open"})


class OpportunityCreate(OpportunityBase):
    project_id: Optional[UUID] = Field(None, json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})


class OpportunityUpdate(OpportunityBase):
    pass


class OpportunityPatch(BaseModel):
    title: Optional[str] = None
    role_type: Optional[str] = None
    purpose: Optional[str] = None
    required_members: Optional[int] = None
    work_start_date: Optional[date] = None
    experience: Optional[str] = None
    requirements: Optional[str] = None
    location: Optional[str] = None
    compensation: Optional[str] = None
    deadline: Optional[date] = None
    status: Optional[str] = None


class OpportunityStatusUpdate(BaseModel):
    status: str = Field(..., json_schema_extra={"example": "closed"})


class OpportunityResponse(OpportunityBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    project_id: Optional[UUID] = None
    production_house_id: UUID
    studio_name: Optional[str] = None
    studio_banner_logo: Optional[str] = None
    project_title: Optional[str] = None
    applications_count: Optional[int] = 0
    created_at: datetime
    updated_at: datetime
