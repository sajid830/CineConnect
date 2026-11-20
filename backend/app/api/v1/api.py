from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    users,
    production_houses,
    projects,
    opportunities,
    applications,
    portfolio,
    posts,
    interactions,
    connections,
    collaborations,
    messages,
    search,
    notifications,
    media,
    dashboard,
)

api_router = APIRouter()

api_router.include_router(health.router, prefix="/health", tags=["Health"])
api_router.include_router(users.router, prefix="/users", tags=["User / Talent Profiles"])
api_router.include_router(production_houses.router, prefix="/production-houses", tags=["Production Houses"])
api_router.include_router(projects.router, prefix="/projects", tags=["Projects"])
api_router.include_router(opportunities.router, prefix="/opportunities", tags=["Opportunities"])
api_router.include_router(applications.router, prefix="/applications", tags=["Applications"])
api_router.include_router(portfolio.router, prefix="/portfolio", tags=["Portfolio Media"])
api_router.include_router(posts.router, prefix="/posts", tags=["Social Posts"])
api_router.include_router(interactions.router, prefix="/interactions", tags=["Interactions"])
api_router.include_router(connections.router, prefix="/connections", tags=["Connections"])
api_router.include_router(collaborations.router, prefix="/collaborations", tags=["Collaborations"])
api_router.include_router(messages.router, prefix="/messages", tags=["Messages"])
api_router.include_router(search.router, prefix="/search", tags=["Global Search"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
api_router.include_router(media.router, prefix="/media", tags=["Media Storage"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["Dashboards"])
