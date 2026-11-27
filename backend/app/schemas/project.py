from datetime import datetime, date
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class ProjectBase(BaseModel):
    title: str = Field(..., json_schema_extra={"example": "Shadows of the Ghats"})
    description: Optional[str] = Field(None, json_schema_extra={"example": "A crime thriller set along the Western Ghats."})
    status: Optional[str] = Field("development", json_schema_extra={"example": "pre_production"})
    project_type: Optional[str] = Field(None, json_schema_extra={"example": "Movie"})
    genre: Optional[str] = Field(None, json_schema_extra={"example": "Thriller / Noir"})
    start_date: Optional[date] = Field(None, json_schema_extra={"example": "2026-12-01"})
    end_date: Optional[date] = Field(None, json_schema_extra={"example": "2027-04-30"})
    budget: Optional[str] = Field(None, json_schema_extra={"example": "₹100 Crores"})


class ProjectCreate(ProjectBase):
    pass


class ProjectUpdate(ProjectBase):
    pass


class ProjectPatch(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    project_type: Optional[str] = None
    genre: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    budget: Optional[str] = None


class ProjectResponse(ProjectBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    production_house_id: UUID
    production_house_name: Optional[str] = None
    production_house_logo: Optional[str] = None
    applications_count: Optional[int] = 0
    created_at: datetime
    updated_at: datetime
