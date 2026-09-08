"""A menu added in a later release must not be hidden by a preference saved before it existed.

The preference used to be a list of visible menus, so any account that had saved the setting lost every
menu added afterwards (that is how 이슈 노트 went missing). It is now applied as a hidden list.
"""
from __future__ import annotations

import json

import server
from js_harness import drain, make_context, stub_fetch


def test_server_stores_hidden_list_and_accepts_legacy_visible_only(auth_client):
    saved = auth_client.put("/api/settings/ui.menus", json={"value": {"visible": ["dashboard", "alerts"]}})
    assert saved.status_code == 200, saved.text
    value = auth_client.get("/api/settings/ui.menus").json()["value"]
    assert value["visible"] == ["dashboard", "alerts"]
    assert set(value["hidden"]) == set(server.MENU_KEYS) - {"dashboard", "alerts"}

    saved = auth_client.put("/api/settings/ui.menus", json={"value": {"hidden": ["history"]}})
    assert saved.status_code == 200, saved.text
    value = auth_client.get("/api/settings/ui.menus").json()["value"]
    assert value["hidden"] == ["history"] and "issues" in value["visible"]


def test_client_treats_legacy_visible_list_as_hiding_only_old_menus():
    context = make_context()
    stub_fetch(context, {}, default=None)
    context.eval("applyServerMenus({visible: ['dashboard', 'alerts']})")
    visible = set(json.loads(context.eval("JSON.stringify([...visibleMenus])")))
    assert visible == {"dashboard", "alerts", "issues"}, "issues did not exist when the legacy list was saved, so it stays visible"
    hidden = json.loads(context.eval("JSON.stringify(menuPreferenceValue().hidden)"))
    assert "issues" not in hidden and "history" in hidden


def test_client_applies_hidden_list_and_local_storage_round_trip():
    context = make_context()
    stub_fetch(context, {}, default=None)
    context.eval("applyServerMenus({visible: ['dashboard'], hidden: ['issues']})")
    assert json.loads(context.eval("JSON.stringify([...visibleMenus].sort())")) == sorted(set(server.MENU_KEYS) - {"issues"})
    # What was written to localStorage is read back to the same set on the next load.
    assert json.loads(context.eval("JSON.stringify([...loadVisibleMenus()].sort())")) == sorted(set(server.MENU_KEYS) - {"issues"})
    # An old-format localStorage array is read the legacy way.
    context.eval("localStorage.setItem(menuPreferenceKey, JSON.stringify(['dashboard']))")
    assert json.loads(context.eval("JSON.stringify([...loadVisibleMenus()].sort())")) == ["dashboard", "issues"]
    drain(context)
