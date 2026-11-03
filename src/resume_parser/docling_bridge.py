"""Local document decoding only; no resume semantics or remote inference."""
import argparse
import json
import os
import platform
import sys
from pathlib import Path


def ocr_options(image: bool = False):
    """Use native OCR on Mac and Tesseract CLI on Linux/WSL2."""
    from docling.datamodel.pipeline_options import OcrMacOptions, TesseractCliOcrOptions

    engine = os.environ.get("RESUME_MATCH_OCR", "auto")
    if engine == "auto":
        engine = "ocrmac" if platform.system() == "Darwin" else "tesseract"
    if engine == "ocrmac":
        if platform.system() != "Darwin":
            raise ValueError("ocrmac requires macOS; use RESUME_MATCH_OCR=tesseract")
        return OcrMacOptions(force_full_page_ocr=image, lang=["zh-Hans", "en-US"])
    if engine == "tesseract":
        return TesseractCliOcrOptions(force_full_page_ocr=image, lang=["chi_sim", "eng"])
    raise ValueError(f"Unsupported RESUME_MATCH_OCR: {engine}")


def decode(path: Path, image: bool = False) -> dict:
    from docling.datamodel.base_models import InputFormat
    from docling.datamodel.pipeline_options import PdfPipelineOptions
    from docling.document_converter import DocumentConverter, PdfFormatOption

    options = PdfPipelineOptions()
    options.do_ocr = True
    options.layout_options.model_spec = options.layout_options.model_spec.model_copy(
        update={"revision": "8f39ad3c0b4c58e9c2d2c84a38465abf757272d8"})
    options.ocr_options = ocr_options(image)
    converter = DocumentConverter(format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=options),
        InputFormat.IMAGE: PdfFormatOption(pipeline_options=options),
    })
    result = converter.convert(path)
    status = result.status.value
    if status != "success":
        raise ValueError(f"Docling status: {status}")
    document = result.document.export_to_dict()
    segments = []
    for item, _ in result.document.iterate_items():
        raw = item.model_dump(mode="json")
        # Table cells are separately retained with their table's provenance.
        texts = [(raw.get("text", ""), raw.get("self_ref", ""))]
        if raw.get("label") == "table":
            texts = [(c.get("text", ""), f'{raw["self_ref"]}/data/table_cells/{i}')
                     for i, c in enumerate(raw.get("data", {}).get("table_cells", []))]
        for text, ref in texts:
            if text.strip():
                segments.append({"id": f"s{len(segments)+1}", "text": text,
                                 "source_ref": ref, "paragraph": len(segments)+1,
                                 "provenance": raw.get("prov", [])})
    if not segments:
        raise ValueError("No text recovered; manual review required")
    return {"schema_version": "0.1", "status": "parsed_requires_review",
            "source": str(path), "segments": segments, "docling": document,
            "ocr_engine": options.ocr_options.kind}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--image", action="store_true")
    args = parser.parse_args()
    try:
        payload = decode(args.input, args.image)
        raw_path = args.output.with_suffix(".docling.json")
        raw_path.write_text(json.dumps(payload.pop("docling"), ensure_ascii=False, indent=2), encoding="utf-8")
        payload["raw_docling_path"] = str(raw_path)
        code = 0
    except Exception as exc:
        payload = {"schema_version": "0.1", "status": "needs_review", "error": str(exc)}
        code = 1
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return code


if __name__ == "__main__":
    sys.exit(main())
