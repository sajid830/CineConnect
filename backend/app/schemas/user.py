from datetime import datetime
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.film_credit import FilmCreditResponse


class UserBase(BaseModel):
    full_name: Optional[str] = Field(None, json_schema_extra={"example": "Jane Doe"})
    role: Optional[str] = Field(None, json_schema_extra={"example": "Actor"})
    location: Optional[str] = Field(None, json_schema_extra={"example": "Mumbai, India"})
    bio: Optional[str] = Field(None, json_schema_extra={"example": "Experienced method actor with 5+ years in feature films."})
    phone: Optional[str] = Field(None, json_schema_extra={"example": "+919876543210"})
    experience_years: Optional[int] = Field(0, json_schema_extra={"example": 5})
    skills: Optional[List[str]] = Field(None, json_schema_extra={"example": ["Method Acting", "Martial Arts", "Horse Riding"]})
    handle: Optional[str] = Field(None, json_schema_extra={"example": "@janedoe_actor"})
    headline: Optional[str] = Field(None, json_schema_extra={"example": "Lead Actor | Trained in Action & Classical Theatre"})
    secondary_crafts: Optional[List[str]] = Field(None, json_schema_extra={"example": ["Voice Artist", "Stunt Performer"]})
    guild_id: Optional[str] = Field(None, json_schema_extra={"example": "CINTAA-504"})
    is_guild_verified: bool = False
    daily_call_sheet_rate: Optional[str] = Field(None, json_schema_extra={"example": "₹65,000 / Day"})
    immediate_availability: Optional[str] = Field(None, json_schema_extra={"example": "Available Tomorrow"})
    verified_gear: Optional[List[str]] = Field(None, json_schema_extra={"example": ["Wireless Lav Mic Kit"]})
    avatar_url: Optional[str] = Field(None, json_schema_extra={"example": "https://cdn.cineconnect.com/avatars/janedoe.jpg"})


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
    handle: Optional[str] = None
    headline: Optional[str] = None
    secondary_crafts: Optional[List[str]] = None
    guild_id: Optional[str] = None
    is_guild_verified: Optional[bool] = None
    daily_call_sheet_rate: Optional[str] = None
    immediate_availability: Optional[str] = None
    verified_gear: Optional[List[str]] = None
    avatar_url: Optional[str] = None


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    account_type: str
    is_verified: bool
    connections_count: int = 0
    endorsements_count: Optional[int] = None
    filmography: List[FilmCreditResponse] = []
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
    handle: Optional[str] = None
    headline: Optional[str] = None
    guild_id: Optional[str] = None
    is_guild_verified: bool = False

