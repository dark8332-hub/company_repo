"""Executes the front-end scripts inside QuickJS with a stub DOM.

The host has no node or browser, so this is the only automated guard for the JavaScript:
every top-level statement runs for real, which catches syntax errors, element ids that are
referenced but missing from the page, and functions used before the file that defines them loads.
"""
import json
import re
from pathlib import Path

import pytest
import quickjs

ROOT = Path(__file__).resolve().parents[1]
ENV_SCRIPT = (Path(__file__).resolve().parent / "js_smoke_env.js").read_text(encoding="utf-8")
SCRIPT_TAG = re.compile(r'<script\s+src="([^"?]+)(?:\?[^"]*)?"', re.IGNORECASE)
ID_ATTR = re.compile(r'\bid="([A-Za-z0-9_-]+)"')


def scripts_of(page: str) -> list[str]:
    html = (ROOT / page).read_text(encoding="utf-8")
    return [match.group(1).lstrip("/") for match in SCRIPT_TAG.finditer(html)]


def ids_of(page: str) -> set[str]:
    return set(ID_ATTR.findall((ROOT / page).read_text(encoding="utf-8")))


def run_page(page: str) -> quickjs.Context:
    context = quickjs.Context()
    context.eval(f"globalThis.__PAGE_IDS__ = {json.dumps(sorted(ids_of(page)))};")
    context.eval(ENV_SCRIPT)
    scripts = scripts_of(page)
    assert scripts, f"{page} loads no scripts"
    for script in scripts:
        source = (ROOT / script).read_text(encoding="utf-8")
        try:
            context.eval(source)
        except quickjs.JSException as error:  # pragma: no cover - the message is the assertion
            pytest.fail(f"{script} (loaded by {page}) failed at top level: {error}")
    return context


def test_index_scripts_execute():
    context = run_page("index.html")
    # Functions every page depends on must be globals after the load order completes.
    for name in ("showPage", "showToast", "loadProviders", "escapeText", "formatDateTime"):
        assert context.eval(f"typeof {name}") == "function", f"{name} is not defined globally"


def test_login_scripts_execute():
    run_page("login.html")


def test_index_has_no_inline_bootstrap_script():
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    assert "XMLHttpRequest" not in html, "index.html still carries the legacy inline provider bootstrap"


def test_every_referenced_script_exists():
    for page in ("index.html", "login.html"):
        for script in scripts_of(page):
            assert (ROOT / script).is_file(), f"{page} references missing script {script}"
