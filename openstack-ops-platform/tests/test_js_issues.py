"""Issue notes front-end: code highlighting escapes everything it does not wrap, Markdown fences carry
their language to the highlighter, and the detail view renders body, snippets, links and timeline."""
from __future__ import annotations

import pytest

from js_harness import drain, make_context, stub_fetch

META = {"statuses": [{"key": k, "label": k} for k in ("open", "in_progress", "on_hold", "resolved")],
        "severities": [{"key": k, "label": k} for k in ("critical", "high", "medium", "low")],
        "categories": [{"key": k, "label": k} for k in ("incident", "other")],
        "languages": ["text", "bash", "python", "log"],
        "transitions": {"open": ["in_progress", "on_hold", "resolved"], "resolved": ["open", "in_progress"]}}
ISSUE = {"id": "i1", "number": 7, "key": "ISS-7", "title": "nova-compute down", "status": "open", "severity": "high", "category": "incident",
         "tags": ["nova", "libvirt"], "body": "## 증상\n- 주기적 down\n\n```bash\nsystemctl status nova-compute # 확인\n```\n<script>alert(1)</script>",
         "assignee": "홍길동", "reporter": "admin", "target": "hcom01", "resolution": "", "provider_id": "p1", "provider_name": "hnti",
         "alert_id": "a1", "work_history_id": "w1", "check_id": None, "created_at": "2026-09-08T01:00:00+00:00", "updated_at": "2026-09-08T02:00:00+00:00", "resolved_at": None,
         "snippet_count": 1, "comment_count": 1,
         "snippets": [{"id": "s1", "issue_id": "i1", "position": 1, "title": "설정", "path": "hcom01:/etc/nova/nova.conf", "language": "ini", "code": "[libvirt]\nvirt_type = kvm\n", "created_by": "admin", "created_at": "2026-09-08T01:30:00+00:00", "updated_at": "2026-09-08T01:30:00+00:00"}],
         "events": [{"id": 2, "issue_id": "i1", "created_at": "2026-09-08T01:40:00+00:00", "actor": "admin", "kind": "comment", "text": "로그 확인 중 <b>"},
                    {"id": 1, "issue_id": "i1", "created_at": "2026-09-08T01:00:00+00:00", "actor": "admin", "kind": "created", "text": "nova-compute down"}],
         "links": {"alert": {"id": "a1", "title": "Compute 서비스 down", "status": "open", "severity": "critical"},
                   "work_history": {"id": "w1", "title": "libvirt 재시작", "status": "in_progress", "work_type": "incident"}}}
SUMMARY = {"total": 3, "active": 2, "by_status": {"open": 1, "in_progress": 1, "on_hold": 0, "resolved": 1},
           "by_severity": {"critical": 1, "high": 1, "medium": 0, "low": 0}, "tags": [{"tag": "nova", "count": 2}]}


@pytest.fixture()
def context():
    ctx = make_context()
    stub_fetch(ctx, {"/api/issues/meta": META, "/api/issues/summary": SUMMARY, "/api/issues/i1": ISSUE, "/api/issues?": {"issues": [ISSUE]}})
    return ctx


def test_highlighter_escapes_and_tags_tokens(context):
    html = context.eval("highlightCode('systemctl status nova-compute # <확인>', 'bash')")
    assert '<span class="tok-keyword">systemctl</span>' in html
    assert '<span class="tok-comment"># &lt;확인&gt;</span>' in html, "comment text is escaped inside its span"
    assert "<확인>" not in html
    log = context.eval("highlightCode('2026-09-08 01:00:00 ERROR nova.compute 10.0.0.5 failed', 'log')")
    assert 'tok-timestamp' in log and 'tok-error">ERROR' in log and 'tok-ip">10.0.0.5' in log
    plain = context.eval("highlightCode('<b>x</b>', 'nope')")
    assert plain == "&lt;b&gt;x&lt;/b&gt;", "unknown languages are plain escaped text"


def test_markdown_fence_carries_language_to_highlighter(context):
    html = context.eval("renderMarkdown('본문\\n```python\\nprint(\"<hi>\")\\n```\\n```\\nplain <x>\\n```')")
    assert 'data-language="python"' in html
    assert '<span class="tok-builtin">print</span>' in html
    assert "&lt;hi&gt;" in html and "<hi>" not in html
    assert '<pre class="md-code">plain &lt;x&gt;</pre>' in html, "a fence without a language stays a plain escaped block"


def test_detail_renders_body_snippets_links_and_timeline(context):
    context.eval("loadIssueMeta().then(() => openIssue('i1'))")
    drain(context)
    assert context.eval("__text('#issueDetailKey')") == "ISS-7"
    body = context.eval("__html('#issueDetailBody')")
    assert "<h4>증상</h4>" in body and "<li>주기적 down</li>" in body
    assert 'tok-keyword">systemctl' in body
    assert "<script>" not in body and "&lt;script&gt;" in body, "body HTML is escaped"
    snippets = context.eval("__html('#issueSnippetList')")
    assert 'data-snippet-id="s1"' in snippets and "hcom01:/etc/nova/nova.conf" in snippets
    assert 'tok-section">[libvirt]' in snippets and 'tok-key">virt_type' in snippets
    assert "2줄" in snippets, "the trailing newline does not count as a line"
    links = context.eval("__html('#issueDetailLinks')")
    assert 'data-issue-link="alert"' in links and "Compute 서비스 down" in links
    assert 'data-issue-link="history"' in links and "libvirt 재시작" in links
    timeline = context.eval("__html('#issueTimeline')")
    assert "로그 확인 중 &lt;b&gt;" in timeline and "<em>등록</em>" in timeline
    transitions = context.eval("__html('#issueDetailTransitions')")
    assert 'data-issue-transition="resolved"' in transitions and 'data-issue-transition="open"' not in transitions
    tags = context.eval("__html('#issueDetailTags')")
    assert 'data-issue-tag="nova"' in tags and 'data-issue-tag="libvirt"' in tags


def test_list_and_summary_render(context):
    context.eval("loadIssues()")
    drain(context)
    cards = context.eval("__html('#issueList')")
    assert 'data-open-issue="i1"' in cards and "ISS-7" in cards and 'class="issue-severity high"' in cards
    assert "⌘ 1" in cards and "✉ 1" in cards
    assert str(context.eval("__text('#issueActiveCount')")) == "2"
    assert str(context.eval("__text('#issueCriticalCount')")) == "1"
    assert str(context.eval("__text('#issueResolvedCount')")) == "1"
    assert str(context.eval("__text('#issueMenuCount')")) == "2" and not context.eval("__hidden('#issueMenuCount')")
    cloud = context.eval("__html('#issueTagCloud')")
    assert 'data-issue-tag="nova"' in cloud and "<em>2</em>" in cloud


def test_editor_prefill_from_alert_scaffolds_body_and_link(context):
    context.eval("loadIssueMeta().then(() => openIssueEditorFrom({alert_id:'a1', alert_title:'Compute 서비스 down', provider_id:'p1', title:'Compute 서비스 down', target:'hcom01', severity:'critical', category:'incident', body:'## 알림\\n- Compute 서비스 down'}))")
    drain(context)
    assert context.eval("__get('#issueAlertId').value") == "a1"
    assert context.eval("__get('#issueTitle').value") == "Compute 서비스 down"
    assert context.eval("__get('#issueSeverity').value") == "critical"
    assert context.eval("__get('#issueBody').value").startswith("## 알림")
    assert "Compute 서비스 down" in context.eval("__html('#issueLinkRow')") and not context.eval("__hidden('#issueLinkRow')")
    assert not context.eval("__hidden('#issueEditor')")
    payload = context.eval("JSON.stringify(issuePayload())")
    assert '"alert_id":"a1"' in payload and '"provider_id":"p1"' in payload
