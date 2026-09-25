#!/usr/bin/env bash
# Layer C: two simulators + emulator mailbox.
# Sessions 1–4: Connect, Availability, Nudge, Deletion.
# Each pair is self-contained: UI_TEST_RESET_AUTH creates new anonymous UIDs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_A="${DUAL_SIM_A:-iPhone 17 Pro}"
SIM_B="${DUAL_SIM_B:-iPhone 17}"
MAILBOX_PORT="${BVT_MAILBOX_PORT:-4739}"

# shellcheck source=Scripts/_ensure_java.sh
source "$ROOT/Scripts/_ensure_java.sh"

mailbox_health() {
  curl -fsS --max-time 1 "http://127.0.0.1:${MAILBOX_PORT}/health" >/dev/null 2>&1
}

# GitHub's macOS image firewall drops inbound connections to python.org's
# Python. curl then waits out --max-time instead of getting "connection refused".
if [[ -n "${GITHUB_ACTIONS:-}" ]] && [[ -x /usr/libexec/ApplicationFirewall/socketfilterfw ]]; then
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off || true
fi

MAILBOX_PID=""
MAILBOX_LOG="${TMPDIR:-/tmp}/ufree-bvt-mailbox.log"
if mailbox_health; then
  echo "▶ Reusing BVT mailbox already listening on 127.0.0.1:${MAILBOX_PORT}"
else
  if lsof -nP -iTCP:"${MAILBOX_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    if pgrep -f "bvt_mailbox.py ${MAILBOX_PORT}" >/dev/null 2>&1; then
      echo "▶ Replacing leftover BVT mailbox on port ${MAILBOX_PORT}"
      pkill -f "bvt_mailbox.py ${MAILBOX_PORT}" || true
      sleep 0.4
    else
      echo "✖ Port ${MAILBOX_PORT} is in use by something other than bvt_mailbox.py" >&2
      lsof -nP -iTCP:"${MAILBOX_PORT}" -sTCP:LISTEN >&2 || true
      exit 1
    fi
  fi
  : >"$MAILBOX_LOG"
  python3 -u "$ROOT/Scripts/bvt_mailbox.py" "$MAILBOX_PORT" >>"$MAILBOX_LOG" 2>&1 &
  MAILBOX_PID=$!
  trap 'kill "$MAILBOX_PID" 2>/dev/null || true' EXIT
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    mailbox_health && break
    sleep 0.2
  done
  if ! mailbox_health; then
    echo "✖ BVT mailbox did not start on 127.0.0.1:${MAILBOX_PORT}" >&2
    if [[ -s "$MAILBOX_LOG" ]]; then
      echo "----- mailbox log -----" >&2
      cat "$MAILBOX_LOG" >&2
    fi
    exit 1
  fi
fi

export UFREE_INTEGRATION_TESTS=1
export BVT_MAILBOX_URL="http://127.0.0.1:${MAILBOX_PORT}"

xcrun simctl boot "$SIM_A" 2>/dev/null || true
xcrun simctl boot "$SIM_B" 2>/dev/null || true

exec firebase emulators:exec --only auth,firestore --project ufree-313a2 \
  "env UFREE_INTEGRATION_TESTS=1 BVT_MAILBOX_URL=${BVT_MAILBOX_URL} bash ${ROOT}/Scripts/_dual_sim_xcodebuild.sh"
