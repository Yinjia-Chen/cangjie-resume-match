#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
cjpm build
cjc validation/matching_checks.cj \
  --import-path target/release --import-path "$RESUME_MATCH_STDX_DIR" \
  -L target/release/resume_match -lresume_match.job_model -lresume_match.matching_agent -lresume_match.resume_parser \
  -L "$RESUME_MATCH_STDX_DIR" -lstdx.encoding.json -o target/matching-checks
target/matching-checks
cjc src/resume_parser/*.cj validation/parser_checks.cj \
  --import-path "$RESUME_MATCH_STDX_DIR" \
  -L "$RESUME_MATCH_STDX_DIR" -lstdx.encoding.json -o target/parser-checks
target/parser-checks
