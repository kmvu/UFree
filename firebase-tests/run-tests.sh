#!/usr/bin/env bash
# Resolve a JDK for the Firestore emulator, then run the rules suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$(dirname "$0")"

java_ok() {
  command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1
}

if ! java_ok; then
  if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
    # Prefer the repo-local Temurin copy (gitignored under .jdk/).
    if compgen -G "$ROOT/.jdk/jdk-*/Contents/Home" > /dev/null; then
      JAVA_HOME="$(echo "$ROOT"/.jdk/jdk-*/Contents/Home | awk '{print $1}')"
    elif compgen -G "$ROOT/.jdk/jdk-*" > /dev/null; then
      JAVA_HOME="$(echo "$ROOT"/.jdk/jdk-* | awk '{print $1}')"
    elif [[ -x /usr/libexec/java_home ]]; then
      JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
    fi
  fi

  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    export JAVA_HOME
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

if ! java_ok; then
  cat >&2 <<'EOF'
Firestore emulator needs Java 21+.

Install one of:
  brew install --cask temurin@21
  # or reuse the repo-local JDK under .jdk/ (created during Phase 1 setup)

Then re-run:
  npm --prefix firebase-tests test
EOF
  exit 1
fi

exec npx firebase emulators:exec --only firestore --project ufree-rules-test \
  "mocha --timeout 20000 'rules.test.js'"
