#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
mode="${1:---full}"
case "$mode" in
    --core-only)
        python3.14 scripts/doctor.py --core-only
        bash validation/check_matching.sh
        ;;
    --full)
        .venv/bin/python scripts/doctor.py
        bash validation/check_matching.sh
        .venv/bin/python -m unittest discover -s validation -p '*_test.py'
        .venv/bin/python validation/make_fixtures.py
        .venv/bin/python - <<'PY'
import os, subprocess, tempfile
from pathlib import Path
root = Path.cwd()
(root / "validation/output/sample.doc").unlink(missing_ok=True)
(root / "validation/output/results.json").unlink(missing_ok=True)
# Each LibreOffice process owns its profile; no shared global profile or existing user session.
with tempfile.TemporaryDirectory(prefix="resume-lo-") as profile:
    subprocess.run([os.environ["SOFFICE_BIN"], "--headless",
                    "-env:UserInstallation=" + Path(profile).as_uri(),
                    "--convert-to", "doc:MS Word 97", "--outdir", str(root / "validation/output"),
                    str(root / "validation/output/sample.docx")], check=True)
if not (root / "validation/output/sample.doc").is_file():
    raise SystemExit("DOC fixture conversion did not create sample.doc")
PY
        .venv/bin/python validation/verify.py
        ;;
    *) echo "Usage: bash scripts/check.sh [--core-only|--full]" >&2; exit 2 ;;
esac
