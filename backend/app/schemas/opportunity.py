from datetime import datetime, date
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class OpportunityBase(BaseModel):
    title: str = Field(..., json_schema_extra={"example": "Lead Female Protagonist (Age 24-30)"})
    role_type: Optional[str] = Field(None, json_schema_extra={"example": "Lead Actress"})
    requirements: Optional[str] = Field(None, json_schema_extra={"example": "Fluent in Hindi, martial arts background preferred."})
    location: Optional[str] = Field(None, json_schema_extra={"example": "Mumbai / Goa"})
    compensation: Optional[str] = Field(None, json_schema_extra={"example": "Competitive / SAG-AFTRA Scale"})
    deadline: Optional[date] = Field(None, json_schema_extra={"example": "2026-12-15"})
    status: Optional[str] = Field("open", json_schema_extra={"example": "open"})


class OpportunityCreate(OpportunityBase):
    project_id: UUID = Field(..., json_schema_extra={"example": "123e4567-e89b-12d3-a456-426614174000"})


class OpportunityUpdate(OpportunityBase):
    pass


class OpportunityPatch(BaseModel):
    title: Optional[str] = None
    role_type: Optional[str] = None
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
    project_id: UUID
    production_house_id: UUID
    created_at: datetime
    updated_at: datetime
