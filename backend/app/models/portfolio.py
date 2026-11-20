import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Text, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship, synonym
from app.db.base import Base


class PortfolioMedia(Base):
    """Media assets uploaded by a talent user for their portfolio."""
    __tablename__ = "portfolio_media"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    talent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    media_type: Mapped[str] = mapped_column(String(50), default="image", nullable=False)  # image, video, audio, document
    media_url: Mapped[str] = mapped_column(String(512), nullable=False)
    thumbnail_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Alias user_id for backward compatibility with existing API endpoints
    user_id = synonym("talent_id")

    # Relationships
    talent: Mapped["User"] = relationship("User", foreign_keys=[talent_id], back_populates="portfolio_items")
    user = synonym("talent")
