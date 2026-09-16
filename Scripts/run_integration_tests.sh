#!/usr/bin/env bash
# Run UFreeIntegrationTests against local Auth + Firestore emulators.
# Uses the repo-local Temurin JDK under .jdk/ when system Java is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=Scripts/_ensure_java.sh
source "$ROOT/Scripts/_ensure_java.sh"

export UFREE_INTEGRATION_TESTS=1

exec firebase emulators:exec --only auth,firestore --project ufree-313a2 \
  "bundle exec fastlane integration_tests"
