#!/usr/bin/env bash
# Layer C: two simulators + emulator mailbox.
# Session 1 (Connect) is the first wired pair.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_A="${DUAL_SIM_A:-iPhone 17 Pro}"
SIM_B="${DUAL_SIM_B:-iPhone 17}"
MAILBOX_PORT="${BVT_MAILBOX_PORT:-4739}"

if ! command -v java >/dev/null 2>&1; then
  if compgen -G "$ROOT/.jdk/jdk-*/Contents/Home" > /dev/null; then
    JAVA_HOME="$(echo "$ROOT"/.jdk/jdk-*/Contents/Home | awk '{print $1}')"
    export JAVA_HOME
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

python3 "$ROOT/Scripts/bvt_mailbox.py" "$MAILBOX_PORT" &
MAILBOX_PID=$!
trap 'kill "$MAILBOX_PID" 2>/dev/null || true' EXIT

export UFREE_INTEGRATION_TESTS=1
export BVT_MAILBOX_URL="http://127.0.0.1:${MAILBOX_PORT}"

xcrun simctl boot "$SIM_A" 2>/dev/null || true
xcrun simctl boot "$SIM_B" 2>/dev/null || true

exec firebase emulators:exec --only auth,firestore --project ufree-313a2 \
  "env UFREE_INTEGRATION_TESTS=1 BVT_MAILBOX_URL=${BVT_MAILBOX_URL} bash ${ROOT}/Scripts/_dual_sim_xcodebuild.sh"
