"""add_cinema_fields_reels_stories_bookmarks

Revision ID: a1b2c3d4e5f6
Revises: 7d55cccd8dc1
Create Date: 2026-11-22 17:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '7d55cccd8dc1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Extend users with film-specific profile attributes
    op.add_column('users', sa.Column('handle', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('headline', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('secondary_crafts', postgresql.ARRAY(sa.String(length=100)), nullable=True))
    op.add_column('users', sa.Column('guild_id', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('is_guild_verified', sa.Boolean(), server_default=sa.text('false'), nullable=False))
    op.add_column('users', sa.Column('daily_call_sheet_rate', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('immediate_availability', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('verified_gear', postgresql.ARRAY(sa.String(length=100)), nullable=True))

    # 2. Extend posts with cinema slate metadata
    op.add_column('posts', sa.Column('video_slate_title', sa.String(length=255), nullable=True))
    op.add_column('posts', sa.Column('smpte_timecode', sa.String(length=50), nullable=True))
    op.add_column('posts', sa.Column('aspect_ratio', sa.String(length=20), server_default='2.39:1', nullable=True))
    op.add_column('posts', sa.Column('tags', postgresql.ARRAY(sa.String(length=100)), nullable=True))

    # 3. Extend interactions with SMPTE timecode
    op.add_column('interactions', sa.Column('timecode', sa.String(length=50), nullable=True))

    # 4. Create bookmarks table
    op.create_table(
        'bookmarks',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('post_id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['post_id'], ['posts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'post_id', name='uq_bookmark_user_post'),
    )
    op.create_index(op.f('ix_bookmarks_post_id'), 'bookmarks', ['post_id'], unique=False)
    op.create_index(op.f('ix_bookmarks_user_id'), 'bookmarks', ['user_id'], unique=False)

    # 5. Create reels table
    op.create_table(
        'reels',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('caption', sa.Text(), nullable=True),
        sa.Column('media_url', sa.String(length=512), nullable=False),
        sa.Column('thumbnail_url', sa.String(length=512), nullable=True),
        sa.Column('audio_track', sa.String(length=255), nullable=True),
        sa.Column('smpte_timecode', sa.String(length=50), nullable=True),
        sa.Column('craft_specialty', sa.String(length=100), nullable=True),
        sa.Column('reel_type', sa.String(length=100), server_default='Cinematography Showreel', nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_reels_user_id'), 'reels', ['user_id'], unique=False)

    # 6. Create stories table
    op.create_table(
        'stories',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('media_url', sa.String(length=512), nullable=False),
        sa.Column('caption', sa.Text(), nullable=True),
        sa.Column('location', sa.String(length=255), nullable=True),
        sa.Column('craft_badge', sa.String(length=100), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_stories_user_id'), 'stories', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_stories_user_id'), table_name='stories')
    op.drop_table('stories')

    op.drop_index(op.f('ix_reels_user_id'), table_name='reels')
    op.drop_table('reels')

    op.drop_index(op.f('ix_bookmarks_user_id'), table_name='bookmarks')
    op.drop_index(op.f('ix_bookmarks_post_id'), table_name='bookmarks')
    op.drop_table('bookmarks')

    op.drop_column('interactions', 'timecode')

    op.drop_column('posts', 'tags')
    op.drop_column('posts', 'aspect_ratio')
    op.drop_column('posts', 'smpte_timecode')
    op.drop_column('posts', 'video_slate_title')

    op.drop_column('users', 'verified_gear')
    op.drop_column('users', 'immediate_availability')
    op.drop_column('users', 'daily_call_sheet_rate')
    op.drop_column('users', 'is_guild_verified')
    op.drop_column('users', 'guild_id')
    op.drop_column('users', 'secondary_crafts')
    op.drop_column('users', 'headline')
    op.drop_column('users', 'handle')
