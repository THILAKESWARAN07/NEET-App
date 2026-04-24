"""Backend runtime tweaks.

This file is imported automatically by Python when the backend directory is on
sys.path. We use it to disable third-party pytest plugin autoloading only when
pytest itself is running, which avoids incompatibilities with the repo's
installed test environment.
"""

from __future__ import annotations

import os


os.environ.setdefault("PYTEST_DISABLE_PLUGIN_AUTOLOAD", "1")
