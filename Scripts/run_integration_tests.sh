#!/usr/bin/env bash
# Run UFreeIntegrationTests against local Auth + Firestore emulators.
# Uses the repo-local Temurin JDK under .jdk/ when system Java is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

java_ok() {
  command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1
}

if ! java_ok; then
  if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
    if compgen -G "$ROOT/.jdk/jdk-*/Contents/Home" > /dev/null; then
      JAVA_HOME="$(echo "$ROOT"/.jdk/jdk-*/Contents/Home | awk '{print $1}')"
    elif [[ -x /usr/libexec/java_home ]]; then
      JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true)"
    fi
  fi

  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    export JAVA_HOME
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

if ! java_ok; then
  cat >&2 <<'EOF'
Firestore Auth/Firestore emulators need Java 21+.

Install one of:
  brew install --cask temurin@21
  # or reuse the repo-local JDK under .jdk/

Then re-run:
  ./Scripts/run_integration_tests.sh
EOF
  exit 1
fi

export UFREE_INTEGRATION_TESTS=1

exec firebase emulators:exec --only auth,firestore --project ufree-313a2 \
  "bundle exec fastlane integration_tests"
