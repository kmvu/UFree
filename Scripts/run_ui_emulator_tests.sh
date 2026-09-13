#!/usr/bin/env bash
# Layer B: emulator-backed UI tests (Auth + Firestore).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v java >/dev/null 2>&1; then
  if compgen -G "$ROOT/.jdk/jdk-*/Contents/Home" > /dev/null; then
    export JAVA_HOME
    JAVA_HOME="$(echo "$ROOT"/.jdk/jdk-*/Contents/Home | awk '{print $1}')"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

export UFREE_INTEGRATION_TESTS=1

exec firebase emulators:exec --only auth,firestore --project ufree-313a2 \
  "bundle exec fastlane ui_emulator_tests"
