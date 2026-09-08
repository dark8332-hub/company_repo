"""Every container that receives a generated <table> must be able to scroll it.

A table's min-content width is its widest unbreakable row, so a table wider than its panel paints
straight through the panel border unless the container scrolls. Inside a grid or flex parent the
same table also refuses to shrink and stretches the whole track, which pushes the layout sideways.
Both were happening on several panels; this pins the fix so a new table cannot quietly regress it.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
CSS = (ROOT / "styles.css").read_text(encoding="utf-8")
HTML = (ROOT / "index.html").read_text(encoding="utf-8")

# id of the element a script fills with a table -> the class that actually does the scrolling.
# Usually the container itself; where the script wraps the table, it is the wrapper's class.
TABLE_CONTAINERS = {
    "hypervisorCapacity": "hypervisor-capacity",
    "projectUsage": "project-usage",
    "storageBackend": "storage-backend",
    "openstackInventory": "openstack-inventory",
    "inventoryHistory": "inventory-history",
    "auditLogList": "audit-table",
    "retentionStorage": "retention-storage",
    "monitoringNodes": "monitoring-nodes",
    "monitoringTargets": "monitoring-targets",
    "monitoringApiProbes": "monitoring-nodes",
    "monitoringHaproxy": "monitoring-nodes",
    "monitoringAlertmanager": "monitoring-nodes",
    "monitoringNodeFilesystems": "monitoring-nodes",
    "monitoringNodeInterfaces": "monitoring-nodes",
    "monitoringQueryResult": "promql-result",
    "nodeManagerList": "node-manager-list",
    "inspectionHistoryList": "inspection-history-table",  # the script wraps the table in this div
}


def declarations_for(selector: str) -> str:
    """Every declaration block whose selector list contains this exact selector."""
    found = []
    for match in re.finditer(r"([^{}]+)\{([^{}]*)\}", CSS):
        selectors = [part.strip() for part in match.group(1).replace("\n", " ").split(",")]
        if any(part == selector or part.endswith(" " + selector) for part in selectors):
            found.append(match.group(2))
    return ";".join(found)


def scrolls(selector: str) -> bool:
    return bool(re.search(r"overflow(-x)?:\s*(auto|scroll)", declarations_for(selector)))


@pytest.mark.parametrize("element_id,css_class", sorted(TABLE_CONTAINERS.items()))
def test_table_container_scrolls_horizontally(element_id, css_class):
    assert f'id="{element_id}"' in HTML, f"#{element_id} is gone; update TABLE_CONTAINERS"
    tag = re.search(rf"<[a-z]+[^>]*id=\"{element_id}\"[^>]*>", HTML)
    assert tag, f"#{element_id} is gone; update TABLE_CONTAINERS"
    on_container = css_class in tag.group(0)
    wrapped = any(f'class="{css_class}"' in path.read_text(encoding="utf-8") for path in (ROOT / "js").glob("*.js"))
    assert on_container or wrapped, f"nothing carries .{css_class} for #{element_id} any more"
    assert scrolls(f".{css_class}"), f".{css_class} holds a table but never scrolls it"


# Wrappers the scripts emit around a table, for containers whose id is generated at render time.
WRAPPER_CLASSES = ["inspection-table-wrap", "inspection-history-table", "inspection-report-body"]


@pytest.mark.parametrize("css_class", WRAPPER_CLASSES)
def test_script_emitted_table_wrappers_scroll(css_class):
    used = any(f'class="{css_class}"' in path.read_text(encoding="utf-8") for path in (ROOT / "js").glob("*.js")) \
        or f'class="{css_class}"' in HTML
    assert used, f".{css_class} is no longer emitted; drop it from WRAPPER_CLASSES"
    assert scrolls(f".{css_class}"), f".{css_class} wraps a table but never scrolls it"


def test_clipping_panels_wrap_their_tables_in_a_scroller():
    """.inspection-group hides overflow to keep its rounded corners, which would cut a wide table off."""
    assert re.search(r"\.inspection-group\{[^}]*overflow:\s*hidden", CSS)
    checklist = (ROOT / "js" / "inspection.js").read_text(encoding="utf-8")
    group = checklist[checklist.index('class="inspection-group$'):]
    group = group[:group.index("</article>")]
    table = group.index("<table")
    assert 'class="inspection-table-wrap"' in group[:table], "the checklist table must sit inside the scrolling wrapper"


@pytest.mark.parametrize("selector", [
    ".dashboard-grid>*",                 # one long note must not widen the row and push the next panel out
    ".dashboard-issues>button>div",      # the 1fr track holding the title and note
    ".dashboard-alerts>button>div",
    ".cluster-node-list article>div",    # same <span><div><strong><small></div><em> row shape
    ".infrastructure-inventory-grid>*",
    ".alert-summary-grid>*",
])
def test_grid_items_can_shrink(selector):
    """A grid/flex item keeps min-width:auto by default and refuses to shrink below its content.

    That is what stretches a track past its container, and it also stops any text-overflow ellipsis
    inside from ever engaging, because the element is never actually narrower than its text.
    """
    assert "min-width:0" in declarations_for(selector).replace(" ", ""), \
        f"{selector} would stretch its grid to fit its widest content"


@pytest.mark.parametrize("selector", [".dashboard-issues small", ".dashboard-alerts small",
                                      ".dashboard-issues strong", ".dashboard-alerts strong",
                                      ".cluster-node-list article strong"])
def test_dashboard_rows_truncate_long_text(selector):
    declarations = declarations_for(selector).replace(" ", "")
    assert "text-overflow:ellipsis" in declarations and "overflow:hidden" in declarations
    assert "white-space:nowrap" in declarations


@pytest.mark.parametrize("selector", [".node-detail-grid section", ".timing-grid>*"])
def test_grid_items_holding_tables_can_shrink_and_scroll(selector):
    declarations = declarations_for(selector)
    assert "min-width:0" in declarations.replace(" ", ""), f"{selector} would stretch its grid to the table's width"
    assert scrolls(selector), f"{selector} holds a table but never scrolls it"


def test_panels_do_not_clip_their_own_tables():
    # overflow:hidden on the panel would cut the table off with no way to reach the rest.
    assert not re.search(r"\.panel\{[^}]*overflow:\s*hidden", CSS)


def test_every_wide_table_class_is_registered():
    """A new .inventory-table target must be added to TABLE_CONTAINERS, not left unchecked."""
    targets = set()
    for path in sorted((ROOT / "js").glob("*.js")):
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r"document\.querySelector\('#([\w-]+)'\)\.innerHTML\s*=\s*[`'\"][^`'\"]{0,300}<table", text, re.S):
            targets.add(match.group(1))
        for match in re.finditer(r"(\w+)\s*=\s*document\.querySelector\('#([\w-]+)'\)", text):
            # Stop at the next function so a later function reusing the same variable name
            # (`box`, `list`) is not credited to this container.
            window = text[match.end():]
            boundary = re.search(r"\n(async )?function ", window)
            window = window[:boundary.start()] if boundary else window
            if re.search(rf"\b{match.group(1)}\.innerHTML\s*=\s*[`'\"][^`'\"]{{0,300}}<table", window, re.S):
                targets.add(match.group(2))
    unregistered = targets - set(TABLE_CONTAINERS)
    assert not unregistered, f"these containers get a table but are not covered here: {sorted(unregistered)}"
