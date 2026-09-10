"""Release version and build identity; generated metadata is optional in a source checkout."""
import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
APP_VERSION = (BASE_DIR / "VERSION").read_text().strip()
BUILD_INFO = {"version": APP_VERSION, "revision": "unknown", "built_at": "", "source_dirty": True}
metadata_path = BASE_DIR / "build-info.json"
if metadata_path.is_file():
    BUILD_INFO.update(json.loads(metadata_path.read_text()))
    APP_VERSION = BUILD_INFO["version"]
