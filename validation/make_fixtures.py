"""Synthetic fixtures, containing no personal resume data."""
from pathlib import Path
from docx import Document
from reportlab.pdfgen import canvas
from PIL import Image, ImageDraw, ImageFont

out = Path("validation/output")
out.mkdir(parents=True, exist_ok=True)
lines = ["Resume verification sample", "Skills: JS, Python, SQL",
         "Experience: 2022-01 to 2024-06", "Project: Built search API; reduced latency 30%",
         "Education: Bachelor", "Coordinated 3 teams to resolve delivery blockers"]
doc = Document()
for line in lines:
    doc.add_paragraph(line)
doc.add_paragraph("技能：仓颉；协作：协调三个团队解决交付阻塞。")
doc.save(out / "sample.docx")
pdf = canvas.Canvas(str(out / "sample.pdf"))
for i, line in enumerate(lines):
    pdf.drawString(40, 780-i*30, line)
pdf.save()
im = Image.new("RGB", (1800, 700), "white")
draw = ImageDraw.Draw(im)
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 36)
for i, line in enumerate(lines):
    draw.text((30, 30+i*80), line, font=font, fill="black")
im.save(out / "sample.png")
