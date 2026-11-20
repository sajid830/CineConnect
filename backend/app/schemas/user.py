from datetime import datetime
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class UserBase(BaseModel):
    full_name: Optional[str] = Field(None, json_schema_extra={"example": "Jane Doe"})
    role: Optional[str] = Field(None, json_schema_extra={"example": "Actor"})
    location: Optional[str] = Field(None, json_schema_extra={"example": "Mumbai, India"})
    bio: Optional[str] = Field(None, json_schema_extra={"example": "Experienced method actor with 5+ years in feature films."})
    phone: Optional[str] = Field(None, json_schema_extra={"example": "+919876543210"})
    experience_years: Optional[int] = Field(0, json_schema_extra={"example": 5})
    skills: Optional[List[str]] = Field(None, json_schema_extra={"example": ["Method Acting", "Martial Arts", "Horse Riding"]})


class UserUpdate(UserBase):
    pass


class UserPatch(BaseModel):
    full_name: Optional[str] = None
    role: Optional[str] = None
    location: Optional[str] = None
    bio: Optional[str] = None
    phone: Optional[str] = None
    experience_years: Optional[int] = None
    skills: Optional[List[str]] = None


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    account_type: str
    is_verified: bool
    created_at: datetime
    updated_at: datetime


class UserSearchResponse(BaseModel):
    items: List[UserResponse]
    total: int


class TalentSummaryResponse(BaseModel):
    """Compact talent profile summary embedded in applications and collaborations."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    full_name: Optional[str] = None
    role: Optional[str] = None
    email: Optional[str] = None
    location: Optional[str] = None
    bio: Optional[str] = None
    experience_years: Optional[int] = 0
    is_verified: bool = False
    skills: Optional[List[str]] = None
    avatar_url: Optional[str] = None

