from typing import Optional, List, Dict, Any
from pydantic import BaseModel


class TalentDashboardResponse(BaseModel):
    total_applications: int
    pending_applications: int
    shortlisted_applications: int
    total_connections: int
    portfolio_count: int
    unread_messages: int
    unread_notifications: int
    recent_applications: List[Dict[str, Any]] = []


class ProductionHouseDashboardResponse(BaseModel):
    total_projects: int
    active_projects: int
    total_opportunities: int
    open_opportunities: int
    total_applications_received: int
    pending_reviews: int
    total_collaborations: int
    recent_opportunities: List[Dict[str, Any]] = []
