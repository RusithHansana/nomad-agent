import sys
from pathlib import Path

import pytest

# Ensure `import src...` works regardless of pytest working directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture(autouse=True)
def _clear_settings_cache() -> None:
    # `src.config.get_settings()` is cached; clear it to prevent cross-test leakage.
    from src.config import get_settings

    get_settings.cache_clear()
