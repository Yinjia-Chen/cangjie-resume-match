#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# SDK envsetup may reference unset variables internally.
set +u
source .tools/cangjie/envsetup.sh
set -u
export DYLD_LIBRARY_PATH="$PWD/.tools/stdx/darwin_aarch64_llvm/dynamic/stdx:${DYLD_LIBRARY_PATH:-}"
cjpm build
cjc validation/matching_checks.cj \
  --import-path target/release --import-path .tools/stdx/darwin_aarch64_llvm/dynamic/stdx \
  -L target/release/resume_match -lresume_match.job_model -lresume_match.matching_agent -lresume_match.resume_parser \
  -L .tools/stdx/darwin_aarch64_llvm/dynamic/stdx -lstdx.encoding.json -o target/matching-checks
target/matching-checks
cjc src/resume_parser/*.cj validation/parser_checks.cj \
  --import-path .tools/stdx/darwin_aarch64_llvm/dynamic/stdx \
  -L .tools/stdx/darwin_aarch64_llvm/dynamic/stdx -lstdx.encoding.json -o target/parser-checks
target/parser-checks
