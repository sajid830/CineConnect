"""separate_projects_jobs_applications

Revision ID: d4e5f6a1b2c3
Revises: c3d4e5f6a1b2
Create Date: 2026-11-26 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'd4e5f6a1b2c3'
down_revision: Union[str, None] = 'c3d4e5f6a1b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. projects table: add project_type column
    op.add_column('projects', sa.Column('project_type', sa.String(length=100), nullable=True))

    # 2. opportunities table:
    #    - make project_id nullable so jobs can exist independently or with a project
    #    - add purpose, required_members, work_start_date
    op.alter_column('opportunities', 'project_id', existing_type=postgresql.UUID(as_uuid=True), nullable=True)
    op.add_column('opportunities', sa.Column('purpose', sa.String(length=100), nullable=True))
    op.add_column('opportunities', sa.Column('required_members', sa.Integer(), server_default='1', nullable=False))
    op.add_column('opportunities', sa.Column('work_start_date', sa.Date(), nullable=True))

    # 3. applications table:
    #    - make opportunity_id nullable so applications can be for projects or jobs
    #    - add project_id column referencing projects(id)
    op.alter_column('applications', 'opportunity_id', existing_type=postgresql.UUID(as_uuid=True), nullable=True)
    op.add_column('applications', sa.Column('project_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('projects.id', ondelete='CASCADE'), nullable=True))
    op.create_index('ix_applications_project_id', 'applications', ['project_id'], unique=False)

    # 4. Update unique constraints on applications:
    #    Drop strict table-level unique constraint if exists, create partial unique indexes
    op.execute("ALTER TABLE applications DROP CONSTRAINT IF EXISTS uq_application_opportunity_talent")
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_app_opp_talent ON applications (opportunity_id, talent_id) WHERE opportunity_id IS NOT NULL")
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_app_proj_talent ON applications (project_id, talent_id) WHERE project_id IS NOT NULL")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_app_proj_talent")
    op.execute("DROP INDEX IF EXISTS uq_app_opp_talent")
    op.create_unique_constraint('uq_application_opportunity_talent', 'applications', ['opportunity_id', 'talent_id'])
    op.drop_index('ix_applications_project_id', table_name='applications')
    op.drop_column('applications', 'project_id')
    op.alter_column('applications', 'opportunity_id', existing_type=postgresql.UUID(as_uuid=True), nullable=False)

    op.drop_column('opportunities', 'work_start_date')
    op.drop_column('opportunities', 'required_members')
    op.drop_column('opportunities', 'purpose')
    op.alter_column('opportunities', 'project_id', existing_type=postgresql.UUID(as_uuid=True), nullable=False)

    op.drop_column('projects', 'project_type')
