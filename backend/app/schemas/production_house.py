from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class ProductionHouseBase(BaseModel):
    company_name: str = Field(..., json_schema_extra={"example": "Red Chillies Entertainment"})
    description: Optional[str] = Field(None, json_schema_extra={"example": "Leading film production and visual effects studio."})
    location: Optional[str] = Field(None, json_schema_extra={"example": "Mumbai, India"})
    specialization: Optional[str] = Field(None, json_schema_extra={"example": "Feature Films, VFX, OTT"})
    website: Optional[str] = Field(None, json_schema_extra={"example": "https://www.redchillies.com"})
    logo_url: Optional[str] = Field(None, json_schema_extra={"example": "https://cdn.cineconnect.com/logos/rc.png"})


class ProductionHouseCreate(ProductionHouseBase):
    pass


class ProductionHouseUpdate(ProductionHouseBase):
    pass


class ProductionHouseResponse(ProductionHouseBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    email: Optional[str] = None
    is_verified: bool = False
    created_at: datetime
    updated_at: datetime
