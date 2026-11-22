from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func, or_, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user, require_talent, require_production_house
from app.models.user import User
from app.models.production_house import ProductionHouse, Project
from app.models.opportunity import Opportunity, Application
from app.models.portfolio import PortfolioMedia
from app.models.social import Connection, Collaboration
from app.models.message import Message
from app.models.notification import Notification
from app.schemas.dashboard import TalentDashboardResponse, ProductionHouseDashboardResponse

router = APIRouter()


@router.get("/talent", response_model=TalentDashboardResponse)
async def get_talent_dashboard(
    current_user: User = Depends(require_talent),
    db: AsyncSession = Depends(get_db),
):
    """Get aggregated analytics and summary data for the talent interface."""
    talent_id = current_user.id

    # 1. Total applications
    total_apps_res = await db.execute(
        select(func.count(Application.id)).where(Application.talent_id == talent_id)
    )
    total_applications = total_apps_res.scalar_one() or 0

    # 2. Pending applications
    pending_apps_res = await db.execute(
        select(func.count(Application.id)).where(
            Application.talent_id == talent_id,
            Application.status.in_(["submitted", "under_review"]),
        )
    )
    pending_applications = pending_apps_res.scalar_one() or 0

    # 3. Shortlisted applications
    shortlisted_apps_res = await db.execute(
        select(func.count(Application.id)).where(
            Application.talent_id == talent_id,
            Application.status == "shortlisted",
        )
    )
    shortlisted_applications = shortlisted_apps_res.scalar_one() or 0

    # 4. Total connections
    connections_res = await db.execute(
        select(func.count(Connection.id)).where(
            Connection.status == "accepted",
            or_(Connection.sender_id == talent_id, Connection.receiver_id == talent_id),
        )
    )
    total_connections = connections_res.scalar_one() or 0

    # 5. Portfolio count
    portfolio_res = await db.execute(
        select(func.count(PortfolioMedia.id)).where(PortfolioMedia.user_id == talent_id)
    )
    portfolio_count = portfolio_res.scalar_one() or 0

    # 6. Unread messages
    unread_msg_res = await db.execute(
        select(func.count(Message.id)).where(
            Message.recipient_id == talent_id,
            Message.is_read == False,
        )
    )
    unread_messages = unread_msg_res.scalar_one() or 0

    # 7. Unread notifications
    unread_notif_res = await db.execute(
        select(func.count(Notification.id)).where(
            Notification.user_id == talent_id,
            Notification.is_read == False,
        )
    )
    unread_notifications = unread_notif_res.scalar_one() or 0

    # 8. Recent 5 applications with opportunity title
    recent_stmt = (
        select(Application, Opportunity.title)
        .join(Opportunity, Application.opportunity_id == Opportunity.id)
        .where(Application.talent_id == talent_id)
        .order_by(Application.created_at.desc())
        .limit(5)
    )
    recent_res = await db.execute(recent_stmt)
    recent_applications = [
        {
            "id": str(app.id),
            "opportunity_id": str(app.opportunity_id),
            "opportunity_title": title,
            "status": app.status,
            "created_at": app.created_at.isoformat(),
        }
        for app, title in recent_res.all()
    ]

    return TalentDashboardResponse(
        total_applications=total_applications,
        pending_applications=pending_applications,
        shortlisted_applications=shortlisted_applications,
        total_connections=total_connections,
        portfolio_count=portfolio_count,
        unread_messages=unread_messages,
        unread_notifications=unread_notifications,
        recent_applications=recent_applications,
    )


@router.get("/production-house", response_model=ProductionHouseDashboardResponse)
async def get_production_house_dashboard(
    current_user: User = Depends(require_production_house),
    db: AsyncSession = Depends(get_db),
):
    """Get aggregated analytics and summary data for the production house interface."""
    # Find PH record
    ph_res = await db.execute(select(ProductionHouse).where(ProductionHouse.user_id == current_user.id))
    ph = ph_res.scalar_one_or_none()
    if not ph:
        return ProductionHouseDashboardResponse(
            total_projects=0,
            active_projects=0,
            total_opportunities=0,
            open_opportunities=0,
            total_applications_received=0,
            pending_reviews=0,
            total_collaborations=0,
            recent_opportunities=[],
        )

    # 1. Total projects
    proj_res = await db.execute(
        select(func.count(Project.id)).where(Project.production_house_id == ph.id)
    )
    total_projects = proj_res.scalar_one() or 0

    # 2. Active projects
    active_proj_res = await db.execute(
        select(func.count(Project.id)).where(
            Project.production_house_id == ph.id,
            Project.status.in_(["development", "pre-production", "filming", "post-production"]),
        )
    )
    active_projects = active_proj_res.scalar_one() or 0

    # 3. Total opportunities
    opp_res = await db.execute(
        select(func.count(Opportunity.id)).where(Opportunity.production_house_id == ph.id)
    )
    total_opportunities = opp_res.scalar_one() or 0

    # 4. Open opportunities
    open_opp_res = await db.execute(
        select(func.count(Opportunity.id)).where(
            Opportunity.production_house_id == ph.id,
            Opportunity.status == "open",
        )
    )
    open_opportunities = open_opp_res.scalar_one() or 0

    # 5. Total applications received
    app_res = await db.execute(
        select(func.count(Application.id))
        .join(Opportunity, Application.opportunity_id == Opportunity.id)
        .where(Opportunity.production_house_id == ph.id)
    )
    total_applications_received = app_res.scalar_one() or 0

    # 6. Pending reviews
    pending_res = await db.execute(
        select(func.count(Application.id))
        .join(Opportunity, Application.opportunity_id == Opportunity.id)
        .where(
            Opportunity.production_house_id == ph.id,
            Application.status.in_(["submitted", "under_review"]),
        )
    )
    pending_reviews = pending_res.scalar_one() or 0

    # 7. Total collaborations
    collab_res = await db.execute(
        select(func.count(Collaboration.id))
        .join(Project, Collaboration.project_id == Project.id)
        .where(Project.production_house_id == ph.id)
    )
    total_collaborations = collab_res.scalar_one() or 0

    # 8. Shortlisted applications
    shortlisted_res = await db.execute(
        select(func.count(Application.id))
        .join(Opportunity, Application.opportunity_id == Opportunity.id)
        .where(
            Opportunity.production_house_id == ph.id,
            Application.status == "shortlisted",
        )
    )
    shortlisted = shortlisted_res.scalar_one() or 0

    # 9. Recent 5 opportunities
    recent_opp_stmt = (
        select(Opportunity)
        .where(Opportunity.production_house_id == ph.id)
        .order_by(Opportunity.created_at.desc())
        .limit(5)
    )
    recent_opp_res = await db.execute(recent_opp_stmt)
    recent_opportunities = [
        {
            "id": str(opp.id),
            "project_id": str(opp.project_id),
            "title": opp.title,
            "role_type": opp.role_type,
            "status": opp.status,
            "deadline": opp.deadline.isoformat() if opp.deadline else None,
            "created_at": opp.created_at.isoformat(),
        }
        for opp in recent_opp_res.scalars().all()
    ]

    # 10. Recent applications
    recent_apps_stmt = (
        select(Application)
        .join(Opportunity, Application.opportunity_id == Opportunity.id)
        .where(Opportunity.production_house_id == ph.id)
        .order_by(Application.created_at.desc())
        .limit(5)
    )
    recent_apps_res = await db.execute(recent_apps_stmt)
    recent_applications = [
        {
            "id": str(app.id),
            "opportunity_id": str(app.opportunity_id),
            "talent_id": str(app.talent_id),
            "status": app.status,
            "reel_url": app.reel_url,
            "resume_url": app.resume_url,
            "cover_letter": app.cover_letter,
            "applied_at": app.created_at.isoformat(),
            "created_at": app.created_at.isoformat(),
        }
        for app in recent_apps_res.scalars().all()
    ]

    return ProductionHouseDashboardResponse(
        total_projects=total_projects,
        active_projects=active_projects,
        total_opportunities=total_opportunities,
        open_opportunities=open_opportunities,
        total_applications_received=total_applications_received,
        pending_reviews=pending_reviews,
        total_collaborations=total_collaborations,
        open_casting_calls=open_opportunities,
        new_applications=pending_reviews,
        shortlisted=shortlisted,
        recent_opportunities=recent_opportunities,
        recent_applications=recent_applications,
    )
