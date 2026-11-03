"""Install project-local tools and Python packages without changing global settings."""
import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "toolchain.lock.json").read_text())


def host_key():
    system, machine = platform.system(), platform.machine().lower()
    if system == "Darwin" and machine == "arm64":
        return "mac-aarch64"
    if system == "Linux" and machine in ("x86_64", "aarch64", "arm64"):
        return "linux-x64" if machine == "x86_64" else "linux-aarch64"
    raise SystemExit("Use Apple Silicon macOS or Linux. On Windows, run inside WSL2; see docs/development.md.")


def run(*args, **kwargs):
    print("+", " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True, **kwargs)


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def download(url, digest, filename):
    cache = ROOT / ".tools/downloads"
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / filename
    if target.exists() and sha256(target) == digest:
        return target
    partial = target.with_suffix(target.suffix + ".part")
    run("curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2",
        "--connect-timeout", "15", "--max-time", "600", url, "--output", partial)
    if sha256(partial) != digest:
        partial.unlink()
        raise SystemExit(f"SHA-256 mismatch: {filename}; no files installed")
    partial.replace(target)
    return target


def in_environment(*args):
    # Keep vendor shell variables scoped to a child process; quote paths as arguments.
    run("bash", "-c", 'source "$1/scripts/env.sh" && shift && "$@"', "setup", ROOT, *args)


def install_mac_converter(force=False):
    app = ROOT / ".tools/libreoffice/LibreOffice.app"
    binary = app / "Contents/MacOS/soffice"
    if binary.is_file():
        return
    if not force and (os.environ.get("SOFFICE_BIN") or shutil.which("soffice")
                      or Path("/Applications/LibreOffice.app/Contents/MacOS/soffice").is_file()):
        print("Using existing LibreOffice; --install-libreoffice installs the pinned project-local copy")
        return
    config = LOCK["libreoffice_mac"]
    archive = download(config["url"], config["sha256"], config["filename"])
    with tempfile.TemporaryDirectory(dir=ROOT / ".tools", prefix="libreoffice-install-") as temp:
        mount = Path(temp) / "mount"
        mount.mkdir()
        run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, archive)
        try:
            staged = Path(temp) / "LibreOffice.app"
            run("ditto", mount / "LibreOffice.app", staged)
            if not (staged / "Contents/MacOS/soffice").is_file():
                raise SystemExit("LibreOffice image has an unexpected layout")
            app.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(staged, app)
        finally:
            run("hdiutil", "detach", mount)
    run("xattr", "-dr", "com.apple.quarantine", app)
    run(binary, "--version")


def install_core(key, force_stdx):
    config = LOCK["supported_platforms"][key]
    tools = ROOT / ".tools"
    tools.mkdir(exist_ok=True)
    sdk = tools / "cangjie"
    if not sdk.exists():
        archive = download(config["sdk_url"], config["sdk_sha256"], f"sdk-{key}-1.0.0.tar.gz")
        with tempfile.TemporaryDirectory(dir=tools, prefix="sdk-extract-") as temp:
            with tarfile.open(archive) as tar:
                tar.extractall(temp, filter="data")
            staged = Path(temp) / "cangjie"
            if not (staged / "bin/cjc").is_file():
                raise SystemExit("SDK archive has an unexpected layout")
            shutil.move(staged, sdk)
        if key.startswith("mac-"):
            run("xattr", "-dr", "com.apple.quarantine", sdk)
    version = subprocess.check_output([sdk / "bin/cjc", "--version"], text=True)
    if "Cangjie Compiler: 1.0.0 " not in version:
        raise SystemExit("Existing .tools/cangjie does not match SDK 1.0.0; move it aside before setup")

    suffix = "dylib" if key.startswith("mac-") else "so"
    dest = tools / "stdx" / config["stdx_directory"]
    output = dest / "dynamic/stdx"
    ready = all((output / f"lib{p}.{suffix}").is_file() and (output / f"{p}.cjo").is_file()
                for p in LOCK["cangjie_stdx"]["source"]["packages"])
    if ready and not force_stdx:
        metadata = json.loads((dest / "package.json").read_text())
        if metadata.get("version") != LOCK["cangjie_stdx"]["version"] or metadata.get("cjc_version") != "1.0.0":
            raise SystemExit("Existing stdx version mismatch; use --rebuild-stdx")
        print("Using existing stdx", metadata["version"], flush=True)
        return
    source = LOCK["cangjie_stdx"]["source"]
    archive = download(source["url"], source["sha256"], f"stdx-{source['revision']}.tar.gz")
    # Build only the two upstream packages imported by this project, including JSON's C FFI.
    # Stage completely before publishing files so a failed build cannot replace a working library.
    with tempfile.TemporaryDirectory(dir=tools, prefix="stdx-build-") as temp:
        work = Path(temp)
        with tarfile.open(archive) as tar:
            tar.extractall(work, filter="data")
        tree = work / f"cangjie_stdx-{source['revision']}" / "src/stdx"
        build = work / "output"
        build.mkdir()
        cc = os.environ.get("CC", "cc")
        c_flags = ["-mmacosx-version-min=12.0"] if key.startswith("mac-") else []
        run(cc, "-fPIC", *c_flags, "-c", tree / "encoding/json/native/json_string_escape.c",
            "-o", build / "json_ffi.o")
        def link_options(package):
            name = f"lib{package}.{suffix}"
            if key.startswith("mac-"):
                # SDK 1.0.0's older ld64.lld emits __DATA_CONST without the flag required
                # by modern dyld. Keep data in __DATA instead, using a linker option.
                return ["--link-options", f"-no_data_const -install_name @rpath/{name}"]
            return [f"--link-options=--soname={name}"]

        in_environment("cjc", *sorted((tree / "serialization/serialization").glob("*.cj")),
                       "--output-type=dylib", *link_options("stdx.serialization.serialization"),
                       "-o", build / f"libstdx.serialization.serialization.{suffix}")
        in_environment("cjc", *sorted((tree / "encoding/json").glob("*.cj")), "--output-type=dylib",
                       *link_options("stdx.encoding.json"),
                       "--import-path", build, "-L", build, "-lstdx.serialization.serialization",
                       build / "json_ffi.o", "-o", build / f"libstdx.encoding.json.{suffix}")
        output.mkdir(parents=True, exist_ok=True)
        for artifact in build.iterdir():
            if artifact.suffix in (".cjo", ".dylib", ".so"):
                shutil.copy2(artifact, output / artifact.name)
        shutil.copy2(work / f"cangjie_stdx-{source['revision']}" / "LICENSE", dest / "LICENSE")
        (dest / "package.json").write_text(json.dumps({"cjc_version": "1.0.0", "version": "1.0.0.1",
            "source_revision": source["revision"], "packages": source["packages"]}, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-only", action="store_true", help="Install SDK/stdx only; no venv or model dependencies")
    parser.add_argument("--rebuild-stdx", action="store_true", help="Rebuild the required stdx packages from pinned source")
    parser.add_argument("--install-libreoffice", action="store_true", help="On Mac, install the pinned project-local converter even if a system copy exists")
    args = parser.parse_args()
    key = host_key()
    if sys.version.split()[0] != LOCK["python"]:
        raise SystemExit(f"Run with Python {LOCK['python']}; current interpreter: {sys.version.split()[0]}")
    for tool in ("bash", "curl", os.environ.get("CC", "cc")):
        if not shutil.which(tool):
            raise SystemExit(f"Missing {tool}; install system prerequisites in docs/development.md")
    install_core(key, args.rebuild_stdx)
    if not args.core_only:
        if key.startswith("mac-"):
            install_mac_converter(args.install_libreoffice)
        python = ROOT / ".venv/bin/python"
        if not python.exists():
            run(sys.executable, "-m", "venv", ROOT / ".venv")
        actual = subprocess.check_output([python, "-c", "import platform; print(platform.python_version())"], text=True).strip()
        if actual != LOCK["python"]:
            raise SystemExit(f"Existing .venv uses {actual}; move it aside and rerun setup")
        if key.startswith("linux-"):
            # Preinstall CPU wheels so pip does not fetch the large CUDA distribution from PyPI.
            run(python, "-m", "pip", "install", "torch==2.15.0", "torchvision==0.29.2",
                "--index-url", "https://download.pytorch.org/whl/cpu")
        run(python, "-m", "pip", "install", "-r", ROOT / "requirements.lock")
        run(python, "-m", "pip", "check")
    print("Setup complete. Next: bash scripts/check.sh" + (" --core-only" if args.core_only else " --full"))


if __name__ == "__main__":
    main()
