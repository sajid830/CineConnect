"""create_film_credits_table

Revision ID: b2c3d4e5f6a1
Revises: a1b2c3d4e5f6
Create Date: 2026-11-22 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a1'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add avatar_url to users table
    op.add_column('users', sa.Column('avatar_url', sa.String(length=512), nullable=True))

    # 2. Create film_credits table
    op.create_table(
        'film_credits',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('film_title', sa.String(length=255), nullable=False),
        sa.Column('release_year', sa.Integer(), nullable=False),
        sa.Column('craft_role', sa.String(length=100), nullable=False),
        sa.Column('director_name', sa.String(length=255), nullable=True),
        sa.Column('studio_banner', sa.String(length=255), nullable=True),
        sa.Column('verified_by_guild', sa.Boolean(), server_default=sa.text('false'), nullable=False),
        sa.Column('guild_verification_hash', sa.String(length=128), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('film_credits')
    op.drop_column('users', 'avatar_url')
