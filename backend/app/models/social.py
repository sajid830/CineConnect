import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy import String, Text, DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship, synonym
from app.db.base import Base


class Post(Base):
    """Feed post published by a user."""
    __tablename__ = "posts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    caption: Mapped[str] = mapped_column(Text, nullable=False)
    media_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    video_slate_title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    smpte_timecode: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    aspect_ratio: Mapped[Optional[str]] = mapped_column(String(20), default="2.39:1", nullable=True)
    tags: Mapped[Optional[List[str]]] = mapped_column(ARRAY(String(100)), nullable=True)

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
    user: Mapped["User"] = relationship("User", back_populates="posts", lazy="selectin")
    interactions: Mapped[List["Interaction"]] = relationship(
        "Interaction", back_populates="post", cascade="all, delete-orphan"
    )
    bookmarks: Mapped[List["Bookmark"]] = relationship(
        "Bookmark", back_populates="post", cascade="all, delete-orphan"
    )


class Interaction(Base):
    """Likes and comments on a post."""
    __tablename__ = "interactions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    post_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    type: Mapped[str] = mapped_column(
        String(50), default="like", nullable=False
    )  # 'like', 'comment'
    comment: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    timecode: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    post: Mapped["Post"] = relationship("Post", back_populates="interactions")
    user: Mapped["User"] = relationship("User", lazy="selectin")


class Bookmark(Base):
    """Saved / bookmarked post by a user."""
    __tablename__ = "bookmarks"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    post_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        UniqueConstraint("user_id", "post_id", name="uq_bookmark_user_post"),
    )

    post: Mapped["Post"] = relationship("Post", back_populates="bookmarks", lazy="selectin")
    user: Mapped["User"] = relationship("User", lazy="selectin")


class Reel(Base):
    """CineReel short-form cinematic vertical showcase."""
    __tablename__ = "reels"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    caption: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    media_url: Mapped[str] = mapped_column(String(512), nullable=False)
    thumbnail_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    audio_track: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    smpte_timecode: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    craft_specialty: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    reel_type: Mapped[Optional[str]] = mapped_column(String(100), default="Cinematography Showreel", nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", lazy="selectin")


class Story(Base):
    """On-Set Story expiring after 24 hours."""
    __tablename__ = "stories"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    media_url: Mapped[str] = mapped_column(String(512), nullable=False)
    caption: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    craft_badge: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    user: Mapped["User"] = relationship("User", lazy="selectin")


class Connection(Base):
    """Follow / connection relationship between two users."""
    __tablename__ = "connections"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    follower_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    following_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(
        String(50), default="pending", nullable=False, index=True
    )  # 'pending', 'accepted', 'rejected'

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Aliases for backwards compatibility with sender/receiver terminology
    sender_id = synonym("follower_id")
    receiver_id = synonym("following_id")

    __table_args__ = (
        UniqueConstraint("follower_id", "following_id", name="uq_connection_follower_following"),
    )

    # Relationships
    follower: Mapped["User"] = relationship("User", foreign_keys=[follower_id], back_populates="following_connections", lazy="selectin")
    following: Mapped["User"] = relationship("User", foreign_keys=[following_id], back_populates="follower_connections", lazy="selectin")
    sender = synonym("follower")
    receiver = synonym("following")


class Collaboration(Base):
    """Project-level collaboration invitation for talent."""
    __tablename__ = "collaborations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    project_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    talent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    role: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(
        String(50), default="invited", nullable=False, index=True
    )  # 'invited', 'accepted', 'rejected', 'completed', 'cancelled'

    invited_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Alias created_at to invited_at for backward compatibility with existing API endpoints
    created_at = synonym("invited_at")

    # Relationships
    project: Mapped["Project"] = relationship("Project", back_populates="collaborations")
    talent: Mapped["User"] = relationship("User", back_populates="collaborations", lazy="selectin")
    messages: Mapped[List["Message"]] = relationship("Message", back_populates="collaboration", cascade="all, delete-orphan")
