import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy import String, Text, Boolean, Integer, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship, synonym
from app.db.base import Base


class User(Base):
    """User account synchronized with Supabase Auth."""
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    account_type: Mapped[str] = mapped_column(
        String(50), default="talent", nullable=False, index=True
    )  # 'talent' or 'production_house'
    full_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    role: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # Craft / primary role
    location: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    experience_years: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    skills: Mapped[Optional[List[str]]] = mapped_column(
        ARRAY(String(100)), nullable=True
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Film-specific professional slate profile attributes
    handle: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    headline: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    secondary_crafts: Mapped[Optional[List[str]]] = mapped_column(ARRAY(String(100)), nullable=True)
    guild_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    is_guild_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    daily_call_sheet_rate: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    immediate_availability: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    verified_gear: Mapped[Optional[List[str]]] = mapped_column(ARRAY(String(100)), nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    production_house: Mapped[Optional["ProductionHouse"]] = relationship(
        "ProductionHouse", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    portfolio_items: Mapped[List["PortfolioMedia"]] = relationship(
        "PortfolioMedia", foreign_keys="PortfolioMedia.talent_id", back_populates="talent", cascade="all, delete-orphan"
    )
    applications: Mapped[List["Application"]] = relationship(
        "Application", back_populates="talent", cascade="all, delete-orphan"
    )
    posts: Mapped[List["Post"]] = relationship(
        "Post", back_populates="user", cascade="all, delete-orphan"
    )
    following_connections: Mapped[List["Connection"]] = relationship(
        "Connection", foreign_keys="Connection.follower_id", back_populates="follower", cascade="all, delete-orphan"
    )
    follower_connections: Mapped[List["Connection"]] = relationship(
        "Connection", foreign_keys="Connection.following_id", back_populates="following", cascade="all, delete-orphan"
    )
    sent_connections = synonym("following_connections")
    received_connections = synonym("follower_connections")

    collaborations: Mapped[List["Collaboration"]] = relationship(
        "Collaboration", back_populates="talent", cascade="all, delete-orphan"
    )
    film_credits: Mapped[List["FilmCredit"]] = relationship(
        "FilmCredit", back_populates="user", cascade="all, delete-orphan"
    )
    sent_messages: Mapped[List["Message"]] = relationship(
        "Message", foreign_keys="Message.sender_id", back_populates="sender", cascade="all, delete-orphan"
    )
    received_messages: Mapped[List["Message"]] = relationship(
        "Message", foreign_keys="Message.recipient_id", back_populates="recipient", cascade="all, delete-orphan"
    )


class FilmCredit(Base):
    """Verified professional film credit / filmography record for a talent user."""
    __tablename__ = "film_credits"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    film_title: Mapped[str] = mapped_column(String(255), nullable=False)
    release_year: Mapped[int] = mapped_column(Integer, nullable=False)
    craft_role: Mapped[str] = mapped_column(String(100), nullable=False)
    director_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    studio_banner: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    verified_by_guild: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    guild_verification_hash: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="film_credits")
