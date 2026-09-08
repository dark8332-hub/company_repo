"""일일점검 내용·이상 항목 보고서 PDF 생성기 (fpdf2 + NanumGothic)."""
from __future__ import annotations

from datetime import datetime
from pathlib import Path

from fpdf import FPDF
from fpdf.fonts import FontFace

FONT_DIR = Path(__file__).resolve().parent / "fonts"
FONT_REGULAR = FONT_DIR / "NanumGothic-Regular.ttf"
FONT_BOLD = FONT_DIR / "NanumGothic-Bold.ttf"

STATUS_LABELS = {"healthy": "정상", "warning": "주의", "pending": "수집 대기", "unavailable": "확인 불가", "skipped": "점검 제외", "excepted": "예외 처리"}
STATUS_COLORS = {"healthy": (31, 143, 84), "warning": (214, 121, 24), "unavailable": (107, 123, 147), "pending": (137, 150, 168), "skipped": (137, 150, 168), "excepted": (31, 143, 84)}
ROW_FILL = {"warning": (255, 250, 243), "unavailable": (247, 249, 251)}
NAVY = (18, 38, 74)
TEXT = (77, 93, 116)
MUTED = (137, 150, 168)
MAX_CELL_CHARS = 700
COLUMNS = ("점검 분류", "점검 사항", "상태", "점검 결과", "특이사항", "직전 대비")
COL_WIDTHS = (24, 60, 18, 84, 66, 25)  # 합계 277mm (A4 가로 297 - 여백 20)


def _clip(value, limit: int = MAX_CELL_CHARS) -> str:
    text = str(value if value is not None else "").replace("\r", "")
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def _format_duration(seconds) -> str:
    if seconds is None:
        return "-"
    total = max(0, int(round(float(seconds))))
    minutes, rest = divmod(total, 60)
    return f"{minutes}분 {rest}초" if minutes else f"{rest}초"


class _ReportPDF(FPDF):
    def __init__(self, provider: str, meta: str, title: str = "일일점검 내용"):
        super().__init__(orientation="L", unit="mm", format="A4")
        self.provider = provider
        self.meta = meta
        self.title_text = title
        self.set_margins(10, 12, 10)
        self.set_auto_page_break(auto=True, margin=14)
        self.add_font("Nanum", "", str(FONT_REGULAR))
        self.add_font("Nanum", "B", str(FONT_BOLD))

    def header(self):
        self.set_font("Nanum", "B", 13)
        self.set_text_color(*NAVY)
        self.cell(0, 7, self.title_text, new_x="LMARGIN", new_y="NEXT")
        self.set_font("Nanum", "", 8.5)
        self.set_text_color(*MUTED)
        self.cell(0, 5, self.meta, new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(226, 233, 240)
        self.line(self.l_margin, self.get_y() + 1, self.w - self.r_margin, self.get_y() + 1)
        self.ln(4)

    def footer(self):
        self.set_y(-10)
        self.set_font("Nanum", "", 7.5)
        self.set_text_color(*MUTED)
        self.cell(0, 5, f"OKESTRO OpenStack Operations Platform · {self.provider}", align="L")
        self.cell(0, 5, f"{self.page_no()} / {{nb}}", align="R")


def build_inspection_pdf(payload: dict) -> bytes:
    provider = str(payload.get("provider") or "-")
    checked_at = str(payload.get("checked_at") or "최근 결과")
    meta_parts = [provider, checked_at]
    if payload.get("trigger") == "scheduled":
        meta_parts.append("예약 실행")
    if payload.get("duration_seconds") is not None:
        meta_parts.append(f"소요 {_format_duration(payload['duration_seconds'])}")
    meta_parts.append(f"생성 {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    groups = [group for group in payload.get("groups") or [] if group.get("rows")]
    rows_all = [row for group in groups for row in group["rows"]]

    pdf = _ReportPDF(provider, " · ".join(meta_parts))
    pdf.alias_nb_pages()
    pdf.add_page()

    counts: dict[str, int] = {}
    for row in rows_all:
        counts[row.get("status", "")] = counts.get(row.get("status", ""), 0) + 1
    summary = [
        ("전체", len(rows_all), NAVY),
        ("정상", counts.get("healthy", 0) + counts.get("excepted", 0), STATUS_COLORS["healthy"]),
        ("주의", counts.get("warning", 0), STATUS_COLORS["warning"]),
        ("확인 불가", counts.get("unavailable", 0), STATUS_COLORS["unavailable"]),
        ("수집 대기·제외", counts.get("pending", 0) + counts.get("skipped", 0), STATUS_COLORS["pending"]),
    ]
    x = pdf.l_margin
    y = pdf.get_y()
    for label, value, color in summary:
        pdf.set_xy(x, y)
        pdf.set_font("Nanum", "", 7.5)
        pdf.set_text_color(*MUTED)
        pdf.cell(34, 4, label, new_x="LEFT", new_y="NEXT")
        pdf.set_font("Nanum", "B", 12)
        pdf.set_text_color(*color)
        pdf.cell(34, 6, str(value))
        x += 38
    pdf.set_xy(pdf.l_margin, y + 13)

    header_style = FontFace(emphasis="BOLD", color=(82, 100, 122), fill_color=(243, 246, 250), size_pt=7.5)
    for index, group in enumerate(groups, start=1):
        rows = group["rows"]
        if pdf.get_y() > pdf.h - 45:
            pdf.add_page()
        pdf.ln(2)
        title = f"{index}. {group.get('title') or '-'}"
        pdf.set_font("Nanum", "B", 10)
        pdf.set_text_color(37, 51, 74)
        title_width = pdf.get_string_width(title)
        pdf.cell(title_width + 3, 6, title, new_x="RIGHT", new_y="TOP")
        pdf.set_font("Nanum", "", 7.5)
        pdf.set_text_color(*MUTED)
        pdf.cell(0, 6, f"{len(rows)}개 항목", new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1)
        pdf.set_font("Nanum", "", 7.5)
        pdf.set_text_color(*TEXT)
        pdf.set_draw_color(227, 233, 240)
        pdf.set_line_width(0.2)
        with pdf.table(col_widths=COL_WIDTHS, headings_style=header_style, line_height=3.8, padding=1.2, text_align="LEFT", v_align="TOP", repeat_headings=1) as table:
            head = table.row()
            for column in COLUMNS:
                head.cell(column)
            for row in rows:
                status = str(row.get("status") or "")
                fill = ROW_FILL.get(status)
                body_style = FontFace(color=TEXT, fill_color=fill) if fill else None
                data_row = table.row(style=body_style) if body_style else table.row()
                data_row.cell(_clip(row.get("category"), 120))
                name = _clip(row.get("name"), 200)
                method = _clip(row.get("method"), 400)
                data_row.cell(f"{name}\n{method}" if method else name, style=FontFace(emphasis="BOLD", color=(37, 51, 74), fill_color=fill))
                data_row.cell(STATUS_LABELS.get(status, status or "-"), style=FontFace(emphasis="BOLD", color=STATUS_COLORS.get(status, TEXT), fill_color=fill))
                data_row.cell(_clip(row.get("result")) or "-")
                data_row.cell(_clip(row.get("note")) or "-")
                data_row.cell(_clip(row.get("change"), 60) or "-")
    return bytes(pdf.output())


ISSUE_COLUMNS = ("영역", "점검 항목", "상태", "특이사항", "결과")
ISSUE_COL_WIDTHS = (42, 62, 20, 78, 75)  # 합계 277mm
MAX_OUTPUT_CHARS = 6000
MAX_OUTPUT_LINES = 80
OUTPUT_FILL = (246, 248, 251)


def _clip_output(value) -> str:
    text = str(value if value is not None else "").replace("\r", "").replace("\t", "    ")
    lines = text.split("\n")
    if len(lines) > MAX_OUTPUT_LINES:
        text = "\n".join(lines[:MAX_OUTPUT_LINES]) + f"\n… 외 {len(lines) - MAX_OUTPUT_LINES}행 생략"
    if len(text) > MAX_OUTPUT_CHARS:
        text = text[: MAX_OUTPUT_CHARS - 1].rstrip() + "…"
    return text or "출력 없음"


def _meta_line(payload: dict) -> tuple[str, str]:
    provider = str(payload.get("provider") or "-")
    meta_parts = [provider, str(payload.get("checked_at") or "최근 결과")]
    if payload.get("trigger") == "scheduled":
        meta_parts.append("예약 실행")
    if payload.get("duration_seconds") is not None:
        meta_parts.append(f"소요 {_format_duration(payload['duration_seconds'])}")
    meta_parts.append(f"생성 {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    return provider, " · ".join(meta_parts)


def build_issue_report_pdf(payload: dict) -> bytes:
    """상단 `PDF 저장`용 이상 항목 요약 보고서: 주의·확인 불가 항목 요약 표와 항목별 판정 근거·원본 결과."""
    provider, meta = _meta_line(payload)
    items = [item for item in payload.get("items") or [] if item.get("status") in ("warning", "unavailable")]

    pdf = _ReportPDF(provider, meta, title="일일점검 이상 항목 보고서")
    pdf.alias_nb_pages()
    pdf.add_page()

    warning = sum(1 for item in items if item.get("status") == "warning")
    unavailable = len(items) - warning
    x = pdf.l_margin
    y = pdf.get_y()
    for label, value, color in (("이상 항목", len(items), NAVY), ("주의", warning, STATUS_COLORS["warning"]), ("확인 불가", unavailable, STATUS_COLORS["unavailable"])):
        pdf.set_xy(x, y)
        pdf.set_font("Nanum", "", 7.5)
        pdf.set_text_color(*MUTED)
        pdf.cell(34, 4, label, new_x="LEFT", new_y="NEXT")
        pdf.set_font("Nanum", "B", 12)
        pdf.set_text_color(*color)
        pdf.cell(34, 6, str(value))
        x += 38
    pdf.set_xy(pdf.l_margin, y + 13)

    if not items:
        pdf.ln(6)
        pdf.set_font("Nanum", "B", 12)
        pdf.set_text_color(*STATUS_COLORS["healthy"])
        pdf.cell(0, 8, "이상 항목 없음", new_x="LMARGIN", new_y="NEXT")
        pdf.set_font("Nanum", "", 9)
        pdf.set_text_color(*TEXT)
        pdf.cell(0, 6, "이번 일일점검에서 주의 또는 확인이 필요한 항목이 발견되지 않았습니다.", new_x="LMARGIN", new_y="NEXT")
        return bytes(pdf.output())

    # 1. 요약 표
    pdf.ln(2)
    pdf.set_font("Nanum", "B", 10)
    pdf.set_text_color(37, 51, 74)
    pdf.cell(0, 6, "1. 이상 항목 요약", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1)
    header_style = FontFace(emphasis="BOLD", color=(82, 100, 122), fill_color=(243, 246, 250), size_pt=7.5)
    pdf.set_font("Nanum", "", 7.5)
    pdf.set_text_color(*TEXT)
    pdf.set_draw_color(227, 233, 240)
    pdf.set_line_width(0.2)
    with pdf.table(col_widths=ISSUE_COL_WIDTHS, headings_style=header_style, line_height=3.8, padding=1.2, text_align="LEFT", v_align="TOP", repeat_headings=1) as table:
        head = table.row()
        for column in ISSUE_COLUMNS:
            head.cell(column)
        for item in items:
            status = str(item.get("status") or "")
            fill = ROW_FILL.get(status)
            row = table.row(style=FontFace(color=TEXT, fill_color=fill)) if fill else table.row()
            row.cell(_clip(item.get("group"), 120) or "-")
            row.cell(_clip(item.get("name"), 200) or "-", style=FontFace(emphasis="BOLD", color=(37, 51, 74), fill_color=fill))
            row.cell(STATUS_LABELS.get(status, status or "-"), style=FontFace(emphasis="BOLD", color=STATUS_COLORS.get(status, TEXT), fill_color=fill))
            row.cell(_clip(item.get("note")) or "-")
            row.cell(_clip(item.get("result")) or "-")

    # 2. 상세 내용
    pdf.ln(5)
    if pdf.get_y() > pdf.h - 40:
        pdf.add_page()
    pdf.set_font("Nanum", "B", 10)
    pdf.set_text_color(37, 51, 74)
    pdf.cell(0, 6, "2. 이상 항목 상세 내용", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Nanum", "", 8)
    pdf.set_text_color(*MUTED)
    pdf.cell(0, 5, "주의 또는 확인이 필요한 항목의 판정 근거와 원본 결과입니다.", new_x="LMARGIN", new_y="NEXT")
    content_width = pdf.w - pdf.l_margin - pdf.r_margin
    for index, item in enumerate(items, start=1):
        status = str(item.get("status") or "")
        if pdf.get_y() > pdf.h - 45:
            pdf.add_page()
        pdf.ln(3)
        pdf.set_draw_color(*STATUS_COLORS.get(status, TEXT))
        pdf.set_line_width(0.8)
        top = pdf.get_y()
        pdf.set_font("Nanum", "", 7.5)
        pdf.set_text_color(*MUTED)
        pdf.set_x(pdf.l_margin + 3)
        pdf.cell(0, 4, f"{index}. {_clip(item.get('group'), 120) or '-'}", new_x="LMARGIN", new_y="NEXT")
        pdf.set_font("Nanum", "B", 10.5)
        pdf.set_text_color(37, 51, 74)
        pdf.set_x(pdf.l_margin + 3)
        name = _clip(item.get("name"), 200) or "-"
        pdf.cell(pdf.get_string_width(name) + 4, 6, name, new_x="RIGHT", new_y="TOP")
        pdf.set_font("Nanum", "B", 8)
        pdf.set_text_color(*STATUS_COLORS.get(status, TEXT))
        pdf.cell(0, 6, STATUS_LABELS.get(status, status or "-"), new_x="LMARGIN", new_y="NEXT")
        pdf.line(pdf.l_margin, top, pdf.l_margin, pdf.get_y())
        pdf.set_line_width(0.2)
        pdf.ln(1)
        pdf.set_font("Nanum", "", 8)
        pdf.set_text_color(*TEXT)
        pdf.multi_cell(content_width, 4, f"점검 방법  {_clip(item.get('method'), 600) or '-'}", new_x="LMARGIN", new_y="NEXT")
        pdf.multi_cell(content_width, 4, f"판정 결과  {_clip(item.get('note'), 600) or '-'} · {_clip(item.get('result'), 600) or '-'}", new_x="LMARGIN", new_y="NEXT")
        outputs = item.get("outputs") or []
        if not outputs:
            outputs = [{"title": "", "output": item.get("note") or item.get("result") or "상세 결과 없음"}]
        for output in outputs:
            pdf.ln(1.5)
            if pdf.get_y() > pdf.h - 30:
                pdf.add_page()
            title = _clip(output.get("title"), 200)
            if title:
                pdf.set_font("Nanum", "B", 7.5)
                pdf.set_text_color(37, 51, 74)
                pdf.cell(0, 4, title, new_x="LMARGIN", new_y="NEXT")
            pdf.set_font("Nanum", "", 6.8)
            pdf.set_text_color(*TEXT)
            pdf.set_fill_color(*OUTPUT_FILL)
            pdf.multi_cell(content_width, 3.3, _clip_output(output.get("output")), fill=True, padding=1.5, new_x="LMARGIN", new_y="NEXT")
    return bytes(pdf.output())
