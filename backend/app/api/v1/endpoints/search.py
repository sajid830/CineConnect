from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import User
from app.models.production_house import ProductionHouse
from app.models.opportunity import Opportunity
from app.schemas.search import GlobalSearchResponse
from app.schemas.user import UserResponse
from app.schemas.production_house import ProductionHouseResponse
from app.schemas.opportunity import OpportunityResponse

router = APIRouter()


@router.get("/", response_model=GlobalSearchResponse)
async def global_search(
    q: str = Query(..., min_length=1, description="Global search query for users, production houses, and opportunities"),
    limit: int = Query(10, ge=1, le=50, description="Max results per entity type"),
    db: AsyncSession = Depends(get_db),
):
    """Unified cross-entity search across Talent, Production Houses, and Casting Opportunities."""
    pattern = f"%{q.strip()}%"

    # 1. Search Users
    users_stmt = (
        select(User)
        .where(
            or_(
                User.full_name.ilike(pattern),
                User.email.ilike(pattern),
                User.bio.ilike(pattern),
                User.location.ilike(pattern),
                User.role.ilike(pattern),
            )
        )
        .limit(limit)
    )
    users_res = await db.execute(users_stmt)
    users = users_res.scalars().all()

    # 2. Search Production Houses
    ph_stmt = (
        select(ProductionHouse)
        .where(
            or_(
                ProductionHouse.company_name.ilike(pattern),
                ProductionHouse.description.ilike(pattern),
                ProductionHouse.location.ilike(pattern),
            )
        )
        .limit(limit)
    )
    ph_res = await db.execute(ph_stmt)
    production_houses = ph_res.scalars().all()

    # 3. Search Opportunities
    opp_stmt = (
        select(Opportunity)
        .where(
            or_(
                Opportunity.title.ilike(pattern),
                Opportunity.role_type.ilike(pattern),
                Opportunity.requirements.ilike(pattern),
                Opportunity.location.ilike(pattern),
            )
        )
        .limit(limit)
    )
    opp_res = await db.execute(opp_stmt)
    opportunities = opp_res.scalars().all()

    return GlobalSearchResponse(
        query=q,
        users=[UserResponse.model_validate(u) for u in users],
        production_houses=[ProductionHouseResponse.model_validate(p) for p in production_houses],
        opportunities=[OpportunityResponse.model_validate(o) for o in opportunities],
    )
