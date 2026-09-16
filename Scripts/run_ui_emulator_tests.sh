#!/usr/bin/env bash
# Layer B: emulator-backed UI tests (Auth + Firestore).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=Scripts/_ensure_java.sh
source "$ROOT/Scripts/_ensure_java.sh"

export UFREE_INTEGRATION_TESTS=1

exec firebase emulators:exec --only auth,firestore --project ufree-313a2 \
  "bundle exec fastlane ui_emulator_tests"
