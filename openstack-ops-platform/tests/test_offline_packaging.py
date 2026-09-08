"""The image has to be self-contained: a closed network has no PyPI and no CDN.

Two failures already happened or were one deploy away from happening.

`Dockerfile` listed the modules to copy by hand and drifted behind the imports. `runbooks.py` and
`inventory_collector.py` were added to `server.py` but never to the COPY line, so the image built
fine and then died on the first import with `ModuleNotFoundError`. Only systemd ran it here, so
nothing caught it. `test_dockerfile_copies_every_imported_module` walks the import graph instead
of trusting the list.

`index.html` and `login.html` pulled Inter and Noto Sans KR from `fonts.googleapis.com` through a
render-blocking `<link>`. On a closed network that request does not fail fast - it waits out the
DNS or connect timeout before the page paints. The fonts now ship in `fonts/web/`, and
`test_no_remote_resources_in_pages` keeps a new CDN reference from sneaking back in.
"""
from __future__ import annotations

import ast
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
DOCKERFILE = (ROOT / "Dockerfile").read_text(encoding="utf-8")
PAGES = ["index.html", "login.html"]
STYLES = ["styles.css", "fonts/web/fonts.css"]

# Only resource loads matter. Text the operator types a URL into - the Prometheus and Grafana
# address placeholders on the settings panel - is not a load and is allowed to mention a host.
RESOURCE_ATTR = re.compile(r"""\b(?:src|href)\s*=\s*["']([^"']+)["']""", re.I)
CSS_URL = re.compile(r"""url\(\s*['"]?([^'")]+)['"]?\s*\)""", re.I)
REMOTE = re.compile(r"^(?:[a-z]+:)?//", re.I)


def copied_paths() -> set[str]:
    paths: set[str] = set()
    for line in DOCKERFILE.splitlines():
        stripped = line.strip()
        if not stripped.upper().startswith("COPY "):
            continue
        # `COPY a.py b.py ./` - everything but the COPY keyword and the destination.
        parts = stripped.split()[1:-1]
        paths.update(part for part in parts if not part.startswith("--"))
    return paths


def local_modules() -> set[str]:
    """Modules `server.py` reaches, directly or through another local module."""
    available = {path.stem for path in ROOT.glob("*.py")}
    seen: set[str] = set()
    pending = ["server"]
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        tree = ast.parse((ROOT / f"{name}.py").read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                found = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                found = [node.module or ""] if node.level == 0 else []
            else:
                continue
            pending.extend(item for item in found if item in available)
    return seen


def test_dockerfile_copies_every_imported_module():
    missing = sorted(f"{name}.py" for name in local_modules() if f"{name}.py" not in copied_paths())
    assert not missing, (
        f"Dockerfile does not COPY {missing}. server.py imports them, so the container dies on "
        "startup with ModuleNotFoundError. Add them to the COPY line."
    )


@pytest.mark.parametrize("asset", ["index.html", "login.html", "styles.css", "login.js", "js", "fonts"])
def test_dockerfile_copies_every_served_asset(asset):
    assert asset in copied_paths(), f"Dockerfile does not COPY {asset}; the served page would 404."


@pytest.mark.parametrize("page", PAGES)
def test_no_remote_resources_in_pages(page):
    remote = [url for url in RESOURCE_ATTR.findall((ROOT / page).read_text(encoding="utf-8")) if REMOTE.match(url)]
    assert not remote, (
        f"{page} loads {remote} from the network. A closed network cannot reach it and a "
        "render-blocking <link> stalls the page until the connect times out. Ship the file instead."
    )


@pytest.mark.parametrize("sheet", STYLES)
def test_no_remote_urls_in_stylesheets(sheet):
    remote = [url for url in CSS_URL.findall((ROOT / sheet).read_text(encoding="utf-8")) if REMOTE.match(url)]
    assert not remote, f"{sheet} fetches {remote[:3]} from the network."


def test_every_referenced_font_file_ships():
    css = (ROOT / "fonts/web/fonts.css").read_text(encoding="utf-8")
    referenced = {url for url in CSS_URL.findall(css)}
    assert referenced, "fonts.css declares no faces; the pages would fall back to system fonts."
    missing = sorted(url for url in referenced
                     if not url.startswith("/fonts/") or not (ROOT / "fonts/web" / url[len("/fonts/"):]).is_file())
    assert not missing, f"fonts.css points at {missing[:5]}, which are not in fonts/web/."


def test_pages_load_the_local_font_stylesheet():
    for page in PAGES:
        assert "/fonts/fonts.css" in (ROOT / page).read_text(encoding="utf-8"), \
            f"{page} does not link the bundled font stylesheet."


def test_requirements_pin_every_third_party_import():
    pins = {line.split("==")[0].split("[")[0].strip().lower()
            for line in (ROOT / "requirements.txt").read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.startswith("#")}
    # Import name to distribution name where they differ.
    required = {"fastapi": "fastapi", "asyncssh": "asyncssh", "httpx": "httpx",
                "cryptography": "cryptography", "fpdf": "fpdf2", "openpyxl": "openpyxl"}
    sources = "\n".join((ROOT / f"{name}.py").read_text(encoding="utf-8") for name in local_modules())
    for module, distribution in required.items():
        if re.search(rf"^(?:import {module}\b|from {module}[\s.])", sources, re.M):
            assert distribution in pins, (
                f"{module} is imported but {distribution} is not pinned in requirements.txt. "
                "A closed network cannot resolve it transitively at build time."
            )
