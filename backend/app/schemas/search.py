from typing import List
from pydantic import BaseModel
from app.schemas.user import UserResponse
from app.schemas.production_house import ProductionHouseResponse
from app.schemas.opportunity import OpportunityResponse


class GlobalSearchResponse(BaseModel):
    query: str
    users: List[UserResponse] = []
    production_houses: List[ProductionHouseResponse] = []
    opportunities: List[OpportunityResponse] = []
