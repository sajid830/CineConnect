from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class FilmCreditBase(BaseModel):
    film_title: str = Field(..., json_schema_extra={"example": "Midnight Solitude"})
    release_year: int = Field(..., ge=1900, le=2100, json_schema_extra={"example": 2026})
    craft_role: str = Field(..., json_schema_extra={"example": "Director of Photography"})
    director_name: Optional[str] = Field(None, json_schema_extra={"example": "Karthik Subbaraj"})
    studio_banner: Optional[str] = Field(None, json_schema_extra={"example": "Stone Bench Films"})


class FilmCreditCreate(FilmCreditBase):
    pass


class FilmCreditUpdate(BaseModel):
    film_title: Optional[str] = None
    release_year: Optional[int] = Field(None, ge=1900, le=2100)
    craft_role: Optional[str] = None
    director_name: Optional[str] = None
    studio_banner: Optional[str] = None


class FilmCreditResponse(FilmCreditBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    verified_by_guild: bool = False
    guild_verification_hash: Optional[str] = None
    created_at: datetime
    updated_at: datetime
