"""Convert the defense markdown guides to styled Word documents.

Usage: python md_to_docx.py input.md output.docx [image_for_<<DIAGRAM>>.png]
Handles #/##/### headings, paragraphs, - bullets, 1. lists, pipe tables,
**bold**, `code`, *italic* and ```latex blocks (set as centred monospace).
"""
import re
import sys

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

GOLD = RGBColor(0x9C, 0x7A, 0x1E)
INK = RGBColor(0x11, 0x11, 0x11)
HEAD_FONT, BODY_FONT = "Bodoni MT", "Calibri"


def shade(cell, hex_fill):
    tc = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_fill)
    tc.append(shd)


def add_runs(par, text, size=None, color=None):
    """Inline **bold**, *italic*, `code`."""
    for tok in re.split(r"(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*)", text):
        if not tok:
            continue
        if tok.startswith("**"):
            r = par.add_run(tok[2:-2]); r.bold = True
        elif tok.startswith("`"):
            r = par.add_run(tok[1:-1]); r.font.name = "Consolas"
        elif tok.startswith("*") and len(tok) > 2:
            r = par.add_run(tok[1:-1]); r.italic = True
        else:
            r = par.add_run(tok)
        if size:
            r.font.size = Pt(size)
        if color is not None:
            r.font.color.rgb = color


def setup(doc):
    st = doc.styles["Normal"]
    st.font.name = BODY_FONT
    st.font.size = Pt(11)
    st.element.rPr.rFonts.set(qn("w:eastAsia"), BODY_FONT)
    for name, size in (("Title", 26), ("Heading 1", 18), ("Heading 2", 14), ("Heading 3", 12)):
        s = doc.styles[name]
        s.font.name = HEAD_FONT
        s.font.size = Pt(size)
        s.font.bold = name != "Title"
        s.font.color.rgb = GOLD if name in ("Heading 2", "Heading 3") else INK
    for sec in doc.sections:
        sec.left_margin = sec.right_margin = Cm(2.2)
        sec.top_margin = sec.bottom_margin = Cm(2.0)


def table(doc, rows):
    header, body = rows[0], rows[1:]
    t = doc.add_table(rows=1, cols=len(header))
    t.style = "Table Grid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, h in enumerate(header):
        c = t.rows[0].cells[i]
        c.text = ""
        add_runs(c.paragraphs[0], h.strip(), 10, RGBColor(0xFF, 0xFF, 0xFF))
        for r in c.paragraphs[0].runs:
            r.bold = True
        shade(c, "1A1A1A")
    for row in body:
        cells = t.add_row().cells
        for i, v in enumerate(row[: len(header)]):
            cells[i].text = ""
            add_runs(cells[i].paragraphs[0], v.strip(), 10)
    doc.add_paragraph()


def convert(src, dst, image=None):
    doc = Document()
    setup(doc)
    lines = open(src, encoding="utf-8").read().splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        s = ln.strip()
        if not s:
            i += 1; continue
        if s == "<<DIAGRAM>>" and image:
            doc.add_picture(image, width=Cm(16)); doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
            i += 1; continue
        if s.startswith("```"):
            i += 1; code = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i]); i += 1
            p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            r = p.add_run("\n".join(code)); r.font.name = "Cambria Math"; r.font.size = Pt(11)
            i += 1; continue
        if s.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = [c for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r"\s*:?-{3,}:?\s*", c) for c in cells):
                    rows.append(cells)
                i += 1
            table(doc, rows); continue
        if s.startswith("# "):
            doc.add_paragraph(s[2:], style="Title")
        elif s.startswith("## "):
            doc.add_heading(s[3:], level=1)
        elif s.startswith("### "):
            doc.add_heading(s[4:], level=2)
        elif s.startswith("#### "):
            doc.add_heading(s[5:], level=3)
        elif re.match(r"^- ", s):
            p = doc.add_paragraph(style="List Bullet"); add_runs(p, s[2:])
        elif re.match(r"^\d+\. ", s) and not s.startswith("**"):
            p = doc.add_paragraph(style="List Number"); add_runs(p, re.sub(r"^\d+\. ", "", s))
        else:
            p = doc.add_paragraph(); add_runs(p, s)
            p.paragraph_format.space_after = Pt(6)
        i += 1
    doc.save(dst)
    print("wrote", dst)


if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
