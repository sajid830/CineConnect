"""add_client_message_id_to_messages

Revision ID: c3d4e5f6a1b2
Revises: b2c3d4e5f6a1
Create Date: 2026-11-25 17:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3d4e5f6a1b2'
down_revision: Union[str, None] = 'b2c3d4e5f6a1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add client_message_id column to messages table
    op.add_column('messages', sa.Column('client_message_id', sa.String(length=100), nullable=True))

    # 2. Add index on client_message_id
    op.create_index('ix_messages_client_message_id', 'messages', ['client_message_id'], unique=False)

    # 3. Add compound unique constraint on (sender_id, client_message_id) for safe idempotency
    op.create_unique_constraint(
        'uq_messages_sender_client_message_id',
        'messages',
        ['sender_id', 'client_message_id'],
    )


def downgrade() -> None:
    op.drop_constraint('uq_messages_sender_client_message_id', 'messages', type_='unique')
    op.drop_index('ix_messages_client_message_id', table_name='messages')
    op.drop_column('messages', 'client_message_id')
