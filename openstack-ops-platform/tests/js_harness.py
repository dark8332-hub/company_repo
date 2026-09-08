"""Loads the real front-end scripts into QuickJS with a DOM stub that can be read back.

test_js_smoke proves the modules load; this harness goes further so tests can call render
functions with real payloads and inspect the markup they produce. Two things the plain smoke
environment cannot do are fixed here:

* the stub hands out a fresh element per querySelector call, so anything written to innerHTML is
  lost - selectors are memoised to one element each, the way a page behaves;
* escapeText round-trips through a DOM node's textContent/innerHTML, which the stub cannot
  emulate, so it would blank out every label under test.
"""
from __future__ import annotations

import json
from pathlib import Path

import quickjs

from test_js_smoke import ENV_SCRIPT, ids_of, scripts_of

ROOT = Path(__file__).resolve().parents[1]

STICKY_DOM = """
(function () {
  const cache = new Map();
  const base = document.querySelector.bind(document);
  document.querySelector = function (selector) {
    if (!cache.has(selector)) cache.set(selector, base(selector));
    return cache.get(selector);
  };
  globalThis.__html = selector => (cache.get(selector) || {}).innerHTML || '';
  globalThis.__text = selector => (cache.get(selector) || {}).textContent || '';
  globalThis.__hidden = selector => !!(cache.get(selector) || {}).hidden;
  globalThis.__disabled = selector => !!(cache.get(selector) || {}).disabled;
  globalThis.__get = selector => document.querySelector(selector);
  globalThis.__set = (selector, key, value) => { document.querySelector(selector)[key] = value; };
}());
"""

REAL_ESCAPE = (
    "globalThis.escapeText = value => String(value === null || value === undefined ? '' : value)"
    ".replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;');"
)


def make_context(page: str = "index.html") -> quickjs.Context:
    context = quickjs.Context()
    context.eval(f"globalThis.__PAGE_IDS__ = {json.dumps(sorted(ids_of(page)))};")
    context.eval(ENV_SCRIPT)
    context.eval(STICKY_DOM)
    for script in scripts_of(page):
        context.eval((ROOT / script).read_text(encoding="utf-8"))
    context.eval(REAL_ESCAPE)
    return context


def drain(context: quickjs.Context, limit: int = 5000) -> None:
    """Run queued promise jobs; QuickJS has no event loop of its own."""
    for _ in range(limit):
        if not context.execute_pending_job():
            return


def stub_fetch(context: quickjs.Context, routes: dict[str, object], default: object | None = None) -> None:
    """Answer fetch() from a {url fragment: body} table and record every requested URL."""
    context.eval(f"globalThis.__routes = {json.dumps(routes)}; globalThis.__default = {json.dumps(default)};")
    context.eval("""
globalThis.__requests = [];
globalThis.fetch = function (url) {
  const target = String(url);
  __requests.push(target);
  const key = Object.keys(__routes).find(fragment => target.indexOf(fragment) >= 0);
  const body = key ? __routes[key] : __default;
  return Promise.resolve({ok: body !== null, status: body === null ? 500 : 200, json: () => Promise.resolve(body)});
};
""")
