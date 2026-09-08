"""The alert summary cards act as filter shortcuts, and refresh has to show that it ran.

Each card must select exactly the alerts it counts, so the number on the card and the list below
can never disagree; test_alerts_features.py covers the matching server-side filter.
"""
from __future__ import annotations

import json
import re

import pytest

from js_harness import ROOT, drain, make_context, stub_fetch

SUMMARY = {"active": 86, "suppressed": 4, "critical": 43,
           "groups": [{"status": "open", "severity": "critical", "count": 42},
                      {"status": "open", "severity": "warning", "count": 42},
                      {"status": "acknowledged", "severity": "critical", "count": 1},
                      {"status": "acknowledged", "severity": "warning", "count": 1},
                      {"status": "resolved", "severity": "critical", "count": 28},
                      {"status": "resolved", "severity": "warning", "count": 22}]}
ALERT = {"id": "a1", "title": "Controller SSH 실패", "description": "hcon03 접속 불가", "severity": "critical",
         "status": "open", "suppressed": False, "target": "hcon03", "provider_name": "hnti",
         "first_detected_at": "2026-09-03T01:00:00+00:00", "last_detected_at": "2026-09-04T01:00:00+00:00",
         "assignee": "", "work_history_title": "", "resolution_note": "", "source_key": "check:endpoint"}
GROUPS = {"groups": [{"key": "g1", "kind": "controller", "title": "Controller 연결 실패", "severity": "critical",
                      "count": 1, "open": 1, "acknowledged": 0, "resolved": 0, "suppressed": 0,
                      "cause": "hcon03 SSH 실패", "last_detected_at": "2026-09-04T01:00:00+00:00", "alerts": [ALERT]}],
          "summary": SUMMARY, "total": 1}
STATS = {"days": 30, "mtta_seconds": 600, "mttr_seconds": 7200, "acknowledged": 2, "resolved": 50,
         "auto_resolved": 10, "created": 60, "stale_days": 3, "stale_count": 0, "recurring": []}


@pytest.fixture()
def context():
    ctx = make_context()
    stub_fetch(ctx, {"/api/alerts/groups": GROUPS, "/api/alerts/stats": STATS,
                     "/api/maintenance-windows": {"windows": []}, "/api/alerts": GROUPS})
    return ctx


def load(ctx) -> None:
    ctx.eval("loadAlerts()")
    drain(ctx)


def last_alerts_request(ctx) -> str:
    return ctx.eval("(__requests.filter(url => url.indexOf('/api/alerts') === 0).pop() || '')")


def click_card(ctx, scope: str) -> None:
    ctx.eval(f"applyAlertScope({json.dumps(scope)})")
    drain(ctx)


def test_summary_counts_come_from_the_summary_payload(context):
    context.eval(f"renderAlertSummary({json.dumps(SUMMARY)}, [])")
    # The stub keeps whatever type was assigned; a real DOM stringifies textContent.
    count = lambda selector: str(context.eval(f"__text({selector!r})"))
    assert count("#activeAlertCount") == "86"
    assert count("#criticalAlertCount") == "43"
    assert count("#warningAlertCount") == "43"  # open 42 + acknowledged 1
    assert count("#resolvedAlertCount") == "50"  # resolved 28 + 22
    assert count("#suppressedAlertCount") == "4"


@pytest.mark.parametrize("scope,expected", [
    ("active", ("active", "")),
    ("critical", ("active", "critical")),
    ("warning", ("active", "warning")),
    ("suppressed", ("suppressed", "")),
    ("resolved", ("resolved", "")),
])
def test_each_card_selects_the_alerts_it_counts(context, scope, expected):
    load(context)
    click_card(context, scope)
    status, severity = expected
    assert context.eval("__get('#alertStatusFilter').value") == status
    assert context.eval("__get('#alertSeverityFilter').value") == severity
    request = last_alerts_request(context)
    assert f"status={status}" in request
    if severity:
        assert f"severity={severity}" in request
    else:
        assert "severity=" not in request


def test_clicking_the_selected_card_again_clears_the_filter(context):
    load(context)
    click_card(context, "resolved")
    assert context.eval("currentAlertScope()") == "resolved"
    click_card(context, "resolved")
    assert context.eval("__get('#alertStatusFilter').value") == ""
    assert context.eval("currentAlertScope()") == ""
    assert "status=" not in last_alerts_request(context)


def test_markup_and_script_agree_on_the_card_scopes(context):
    # The stub DOM cannot enumerate elements, so the page/script contract is checked against the
    # markup itself: every card must carry a scope the script knows, and be a real pressed-state button.
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    grid = html[html.index('id="alertSummaryGrid"'):]
    grid = grid[:grid.index("</section>")]
    scopes = re.findall(r'data-alert-scope="([a-z]+)"', grid)
    known = json.loads(context.eval("JSON.stringify(Object.keys(alertScopes))"))
    assert scopes == ["active", "critical", "warning", "suppressed", "resolved"]
    assert set(scopes) == set(known), "a card scope with no entry in alertScopes would do nothing when clicked"
    assert grid.count("<button") == len(scopes), "cards must be buttons so they are keyboard reachable"
    assert grid.count('aria-pressed="false"') == len(scopes)


def test_selected_state_survives_a_reload(context):
    load(context)
    click_card(context, "critical")
    assert context.eval("currentAlertScope()") == "critical"
    load(context)  # a plain refresh must keep the card selection
    assert context.eval("currentAlertScope()") == "critical"
    assert "severity=critical" in last_alerts_request(context)


def test_refresh_reports_that_it_ran(context):
    load(context)
    meta = context.eval("__text('#alertListMeta')")
    assert "1건을 1개 원인으로 묶었습니다" in meta and "갱신" in meta
    click_card(context, "warning")
    assert "주의만 표시" in context.eval("__text('#alertListMeta')")
    assert context.eval("__disabled('#refreshAlerts')") is False, "the busy state must be cleared when the load finishes"


def test_refresh_button_is_released_even_when_the_request_fails(context):
    stub_fetch(context, {}, default=None)  # every route answers 500
    load(context)
    assert context.eval("__disabled('#refreshAlerts')") is False
    assert "error" in context.eval("__html('#alertManagementList')")


def test_empty_result_explains_how_to_clear_the_card_filter(context):
    stub_fetch(context, {"/api/alerts/groups": {"groups": [], "summary": SUMMARY, "total": 0},
                         "/api/alerts/stats": STATS, "/api/maintenance-windows": {"windows": []}})
    load(context)
    click_card(context, "suppressed")
    assert "억제 중에 해당하는 알림이 없습니다" in context.eval("__html('#alertManagementList')")
