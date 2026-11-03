# Source from bash or zsh: source /path/to/repo/scripts/env.sh
if [ -n "${ZSH_VERSION:-}" ]; then
    _resume_env_file="${(%):-%N}"
else
    _resume_env_file="${BASH_SOURCE[0]}"
fi
export RESUME_MATCH_ROOT="$(cd "$(dirname "$_resume_env_file")/.." && pwd)"
case "$(uname -s):$(uname -m)" in
    Darwin:arm64) _resume_platform=darwin_aarch64_llvm ;;
    Linux:x86_64) _resume_platform=linux_x86_64_llvm ;;
    Linux:aarch64|Linux:arm64) _resume_platform=linux_aarch64_llvm ;;
    *) echo 'Unsupported host. Use Apple Silicon macOS or Linux/Windows WSL2 (see docs/development.md).' >&2; return 1 ;;
esac
export CANGJIE_HOME="$RESUME_MATCH_ROOT/.tools/cangjie"
export RESUME_MATCH_STDX_DIR="${RESUME_MATCH_STDX_DIR:-$RESUME_MATCH_ROOT/.tools/stdx/$_resume_platform/dynamic/stdx}"
if [ ! -x "$CANGJIE_HOME/bin/cjc" ]; then
    echo 'Missing Cangjie SDK. Run python3.14 scripts/setup.py first.' >&2
    return 1
fi
export PATH="$RESUME_MATCH_ROOT/.venv/bin:$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:$PATH"
if [ "$(uname -s)" = Darwin ]; then
    export DYLD_LIBRARY_PATH="$RESUME_MATCH_STDX_DIR:$CANGJIE_HOME/runtime/lib/$_resume_platform:$CANGJIE_HOME/tools/lib:${DYLD_LIBRARY_PATH:-}"
    if [ -z "${SDKROOT:-}" ]; then
        export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
    fi
else
    export LD_LIBRARY_PATH="$RESUME_MATCH_STDX_DIR:$CANGJIE_HOME/runtime/lib/$_resume_platform:$CANGJIE_HOME/tools/lib:${LD_LIBRARY_PATH:-}"
fi
if [ -z "${SOFFICE_BIN:-}" ]; then
    if command -v soffice >/dev/null 2>&1; then
        export SOFFICE_BIN="$(command -v soffice)"
    elif [ -x /Applications/LibreOffice.app/Contents/MacOS/soffice ]; then
        export SOFFICE_BIN=/Applications/LibreOffice.app/Contents/MacOS/soffice
    fi
fi
unset _resume_env_file _resume_platform
