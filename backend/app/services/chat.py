import uuid
from typing import Optional
from sqlalchemy import select, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.social import Collaboration
from app.models.production_house import Project, ProductionHouse


async def get_accepted_collaboration(
    session: AsyncSession,
    user_a_id: uuid.UUID,
    user_b_id: uuid.UUID,
) -> Optional[Collaboration]:
    """
    Verifies whether two canonical users (one Talent and one Production House)
    have an accepted project collaboration.

    Returns the accepted Collaboration record if one exists, otherwise None.
    Rejects invitations with status 'invited', 'rejected', 'declined', or 'cancelled'.
    """
    if user_a_id == user_b_id:
        return None

    stmt = (
        select(Collaboration)
        .join(Project, Collaboration.project_id == Project.id)
        .join(ProductionHouse, Project.production_house_id == ProductionHouse.id)
        .where(
            Collaboration.status == "accepted",
            Collaboration.deleted_at.is_(None),
            or_(
                and_(Collaboration.talent_id == user_a_id, ProductionHouse.user_id == user_b_id),
                and_(Collaboration.talent_id == user_b_id, ProductionHouse.user_id == user_a_id),
            ),
        )
        .limit(1)
    )
    result = await session.execute(stmt)
    return result.scalar_one_or_none()
