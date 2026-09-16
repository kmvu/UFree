#!/usr/bin/env bash
# Resolve a JDK for the Firestore emulator, then run the rules suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$(dirname "$0")"
# shellcheck source=Scripts/_ensure_java.sh
source "$ROOT/Scripts/_ensure_java.sh"

exec npx firebase emulators:exec --only firestore --project ufree-rules-test \
  "mocha --timeout 20000 'rules.test.js'"
