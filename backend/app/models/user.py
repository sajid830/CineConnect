import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy import String, Text, Boolean, Integer, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
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
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    production_house: Mapped[Optional["ProductionHouse"]] = relationship(
        "ProductionHouse", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    portfolio_items: Mapped[List["PortfolioMedia"]] = relationship(
        "PortfolioMedia", back_populates="user", cascade="all, delete-orphan"
    )
    applications: Mapped[List["Application"]] = relationship(
        "Application", back_populates="talent", cascade="all, delete-orphan"
    )
    posts: Mapped[List["Post"]] = relationship(
        "Post", back_populates="user", cascade="all, delete-orphan"
    )
    sent_connections: Mapped[List["Connection"]] = relationship(
        "Connection", foreign_keys="Connection.sender_id", back_populates="sender", cascade="all, delete-orphan"
    )
    received_connections: Mapped[List["Connection"]] = relationship(
        "Connection", foreign_keys="Connection.receiver_id", back_populates="receiver", cascade="all, delete-orphan"
    )
    collaborations: Mapped[List["Collaboration"]] = relationship(
        "Collaboration", back_populates="talent", cascade="all, delete-orphan"
    )
    sent_messages: Mapped[List["Message"]] = relationship(
        "Message", foreign_keys="Message.sender_id", back_populates="sender", cascade="all, delete-orphan"
    )
    received_messages: Mapped[List["Message"]] = relationship(
        "Message", foreign_keys="Message.recipient_id", back_populates="recipient", cascade="all, delete-orphan"
    )
    notifications: Mapped[List["Notification"]] = relationship(
        "Notification", back_populates="user", cascade="all, delete-orphan"
    )
