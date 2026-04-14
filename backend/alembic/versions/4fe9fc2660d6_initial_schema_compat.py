"""initial schema compat

Revision ID: 4fe9fc2660d6
Revises:
Create Date: 2026-04-14 12:30:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '4fe9fc2660d6'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Compatibility no-op for environments that were stamped with 4fe9fc2660d6.
    pass


def downgrade() -> None:
    pass
