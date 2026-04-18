"""add image_url to questions

Revision ID: 7f1f9f2f0f3f
Revises: 2698add98b67
Create Date: 2026-04-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7f1f9f2f0f3f'
down_revision: Union[str, None] = '2698add98b67'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('questions', sa.Column('image_url', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('questions', 'image_url')