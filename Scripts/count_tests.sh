#!/usr/bin/env bash
# Count XCTest methods under UFreeTests (live inventory — do not hardcode in docs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Prefer ripgrep; fall back to grep. Never fail the pipeline on "no match" exit codes.
if command -v rg >/dev/null 2>&1; then
  count="$(rg -c --no-messages '^\s*func test_' UFreeTests -g '*.swift' 2>/dev/null \
    | awk -F: '{ s += $NF } END { print s+0 }' || true)"
else
  count="$(grep -R -h -E '^\s*func test_' UFreeTests --include='*.swift' 2>/dev/null \
    | wc -l | tr -d ' ' || true)"
fi

echo "UFreeTests test methods: ${count:-0}"
