"""Run after sourcing SDK envsetup and setting DYLD_LIBRARY_PATH (see report)."""
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
results = []
for ext in ("docx", "pdf", "png", "doc"):
    with tempfile.TemporaryDirectory(prefix="resume-verify-") as temp:
        scratch = Path(temp) / "run"
        command = [str(root / "target/release/bin/main"),
                   str(root / f"validation/output/sample.{ext}"), str(scratch),
                   str(root / ".venv/bin/python"),
                   str(root / "src/resume_parser/docling_bridge.py"), shutil.which("soffice")]
        result = subprocess.run(command, capture_output=True, text=True, timeout=360)
        assert result.returncode == 0, result.stdout + result.stderr
        payload = json.loads((scratch / "resume.json").read_text())
        segments = payload["document"]["segments"]
        text = " ".join(s["text"] for s in segments)
        assert "Python" in text and "2022-01" in text and "30%" in text, text
        assert all(payload[k]["status"] == "未知" for k in
                   ("skills", "experiences", "projects", "education", "behavior_evidence"))
        assert all(s["source_ref"] and s["paragraph"] > 0 for s in segments)
        if ext in ("pdf", "png"):
            assert any(s["provenance"] for s in segments)
        # Keep evidence files; the source paths record the original temporary run.
        dest = root / "validation/output" / f"verified-{ext}"
        shutil.copytree(scratch, dest, dirs_exist_ok=True)
        results.append({"format": ext, "result": "PASS", "segments": len(segments),
                        "text": text, "source_positions": True})
(root / "validation/output/results.json").write_text(
    json.dumps(results, ensure_ascii=False, indent=2))
print(json.dumps(results, ensure_ascii=False, indent=2))
