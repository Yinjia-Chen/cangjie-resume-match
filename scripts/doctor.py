"""Check the installed development environment; never download or install anything."""
import argparse
import importlib.metadata
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "toolchain.lock.json").read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-only", action="store_true")
    args = parser.parse_args()
    failures = []

    def check(ok, label):
        print(f"{'OK' if ok else 'FAIL'} {label}")
        if not ok:
            failures.append(label)

    check(platform.python_version() == LOCK["python"], f"Python {LOCK['python']}")
    cjc = shutil.which("cjc")
    version = subprocess.check_output([cjc, "--version"], text=True) if cjc else ""
    check("Cangjie Compiler: 1.0.0 " in version, "Cangjie SDK 1.0.0")
    stdx = Path(os.environ.get("RESUME_MATCH_STDX_DIR", "/missing"))
    suffix = "dylib" if platform.system() == "Darwin" else "so"
    check(all((stdx / f"lib{p}.{suffix}").is_file() and (stdx / f"{p}.cjo").is_file()
              for p in LOCK["cangjie_stdx"]["source"]["packages"]), "stdx JSON/serialization libraries")
    if not args.core_only:
        check(Path(sys.prefix).resolve() == (ROOT / ".venv").resolve(), "Project .venv is active")
        mismatches = []
        for line in (ROOT / "requirements.lock").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            if ";" in line and platform.system() != "Darwin":
                continue
            name, expected = line.split(";", 1)[0].strip().split("==")
            try:
                actual = importlib.metadata.version(name)
            except importlib.metadata.PackageNotFoundError:
                actual = "missing"
            if actual.split("+", 1)[0] != expected:
                mismatches.append(f"{name}: {actual}, expected {expected}")
        check(not mismatches, "Python package versions match requirements.lock")
        for mismatch in mismatches:
            print(" ", mismatch)
        pip = subprocess.run([sys.executable, "-m", "pip", "check"], capture_output=True, text=True)
        check(pip.returncode == 0, "pip dependency consistency")
        if pip.returncode:
            print(pip.stdout, pip.stderr)
        soffice = os.environ.get("SOFFICE_BIN") or shutil.which("soffice")
        check(bool(soffice and Path(soffice).is_file() and os.access(soffice, os.X_OK)), "LibreOffice / SOFFICE_BIN")
        engine = os.environ.get("RESUME_MATCH_OCR", "auto")
        if engine == "auto":
            engine = "ocrmac" if platform.system() == "Darwin" else "tesseract"
        check(engine in ("ocrmac", "tesseract"), "OCR engine selection")
        if engine == "tesseract":
            executable = shutil.which("tesseract")
            languages = subprocess.check_output([executable, "--list-langs"], text=True) if executable else ""
            check(all(re.search(rf"^{name}$", languages, re.M) for name in ("eng", "chi_sim")), "Tesseract English/Simplified Chinese data")
        elif engine == "ocrmac":
            check(platform.system() == "Darwin", "Apple Vision OCR host")
        print("Model weights are validated by --full, including actual PDF/image parsing.")
    if failures:
        raise SystemExit(f"{len(failures)} check(s) failed. See docs/development.md.")


if __name__ == "__main__":
    main()
