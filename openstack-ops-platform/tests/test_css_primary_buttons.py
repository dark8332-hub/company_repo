"""`.primary-button` must actually look primary wherever it is used.

`.primary-button` has specificity (0,1,0), so any container rule of the form `.box button` (0,1,1)
outranks it and takes over background and colour. The button then keeps the height and the navy
drop shadow that only `.primary-button` sets, while its face turns white with grey text - it reads
as a floating label with a shadow under it rather than a button. This bit the inventory collect
button, the runbook save button and the provider diagnosis button.

A container may legitimately restyle its primary button, but it has to do so with a selector that
outranks the `button` rule it also owns. That is what this checks.
"""
from __future__ import annotations

import re
from html.parser import HTMLParser
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
CSS = (ROOT / "styles.css").read_text(encoding="utf-8")
FACE = re.compile(r"background:|(?<!border-)color:")

RULES = [(selector.strip(), match.group(2), match.start())
         for match in re.finditer(r"([^{}]+)\{([^{}]*)\}", CSS)
         for selector in match.group(1).replace("\n", " ").split(",")]


def specificity(selector: str) -> tuple[int, int, int]:
    return (selector.count("#"),
            len(re.findall(r"\.[\w-]+", selector)),
            len(re.findall(r"(?:^|[\s>+~])([a-z]+)", selector)))


def _prefix_classes(selector: str, tail: str) -> list[str]:
    head = selector[:selector.rfind(tail)]
    return [part.lstrip(".") for part in re.split(r"[\s>]+", head) if part.startswith(".")]


class PrimaryButtons(HTMLParser):
    """Every <button class="primary-button"> with the set of class names above it."""

    def __init__(self) -> None:
        super().__init__()
        self.stack: list[tuple[str, list[str]]] = []
        self.found: list[tuple[str, set[str], set[str]]] = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        classes = (attributes.get("class") or "").split()
        if tag == "button" and "primary-button" in classes:
            ancestors = {name for _, names in self.stack for name in names} | set(classes)
            self.found.append((attributes.get("id") or f"(unnamed, in .{'.'.join(classes)})", ancestors, set(classes)))
        if tag not in ("br", "input", "img", "hr", "meta", "link"):
            self.stack.append((tag, classes))

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                return


def primary_buttons(page: str) -> list[tuple[str, set[str], set[str]]]:
    parser = PrimaryButtons()
    parser.feed((ROOT / page).read_text(encoding="utf-8"))
    return parser.found


def strongest(candidates):
    best = None
    for selector, body, position in candidates:
        if best is None or (specificity(selector), position) > (specificity(best[0]), best[2]):
            best = (selector, body, position)
    return best


def overriding_container_rule(ancestors: set[str]):
    """The winning `.<ancestor> button` rule that repaints the button's face."""
    return strongest([(selector, body, position) for selector, body, position in RULES
                      if re.search(r"(^|[\s>])button$", selector) and FACE.search(body)
                      and (classes := _prefix_classes(selector, "button")) and all(name in ancestors for name in classes)])


def restoring_rule(ancestors: set[str], own: set[str]):
    """The winning rule that targets the button through one of its own classes and repaints its face.

    Either .primary-button or a class the button also carries (.diagnosis-run) counts: both name the
    element itself rather than the container, so both can outrank the container's `button` rule.
    """
    candidates = []
    for selector, body, position in RULES:
        if not FACE.search(body) or selector.rstrip().endswith("span"):
            continue
        tail = re.split(r"[\s>]+", selector.strip())[-1]
        if ":" in tail:
            continue
        classes = set(re.findall(r"\.([\w-]+)", tail))
        if not classes or not classes <= own:
            continue
        if all(name in ancestors for name in _prefix_classes(selector, tail)):
            candidates.append((selector, body, position))
    return strongest(candidates)


CASES = [(page, name, ancestors, own) for page in ("index.html", "login.html") for name, ancestors, own in primary_buttons(page)]


@pytest.mark.parametrize("page,name,ancestors,own", CASES, ids=[f"{page}:{name}" for page, name, _a, _o in CASES])
def test_primary_button_keeps_its_face(page, name, ancestors, own):
    override = overriding_container_rule(ancestors)
    if override is None:
        return  # nothing competes with .primary-button here
    restore = restoring_rule(ancestors, own)
    assert restore is not None, (
        f"{name}: '{override[0]}' repaints it and no rule names .primary-button to restore it")
    assert (specificity(restore[0]), restore[2]) > (specificity(override[0]), override[2]), (
        f"{name}: '{override[0]}' outranks '{restore[0]}', so the button keeps .primary-button's "
        f"height and shadow but loses its navy face")


def test_the_known_offenders_stay_fixed():
    for selector in (".inventory-panel .panel-heading .primary-button",
                     ".runbook-form-actions .primary-button",
                     ".provider-diagnosis .panel-heading .diagnosis-run"):
        body = "".join(rule_body for rule_selector, rule_body, _ in RULES if rule_selector == selector)
        assert "background:" in body and "color:" in body, f"{selector} lost its explicit face"


def test_runbook_action_row_can_wrap():
    """The hint text is long and the runbook panel is half a column wide; a nowrap row squeezes the buttons."""
    row = "".join(body for selector, body, _ in RULES if selector == ".runbook-form-actions")
    assert "flex-wrap:wrap" in row.replace(" ", "")
    buttons = "".join(body for selector, body, _ in RULES if selector == ".runbook-form-actions button")
    assert "flex:0 0 auto" in buttons.replace("  ", "") and "white-space:nowrap" in buttons


def test_every_css_variable_used_is_defined():
    """An undefined var() makes the whole declaration invalid, so the button silently loses its
    background - the overcommit toggle's active state rendered as an empty box because of one."""
    defined = set(re.findall(r"(--[\w-]+)\s*:", CSS))
    used = set(re.findall(r"var\((--[\w-]+)", CSS))
    assert used <= defined, f"used but never defined: {sorted(used - defined)}"


@pytest.mark.parametrize("heading", [".page-heading", ".dashboard-heading"])
def test_heading_description_rules_do_not_stack_button_icons(heading):
    """`<heading> span{display:block}` also matches the icon <span> inside a heading's primary
    button and stacks it above the label. The description span must be targeted more narrowly."""
    for selector, body, _ in RULES:
        if selector.startswith(heading) and selector.endswith("span") and "display:block" in body.replace(" ", ""):
            assert ">div>span" in selector.replace(" ", ""), \
                f"'{selector}' also hits the icon inside .primary-button; scope it to the description"
