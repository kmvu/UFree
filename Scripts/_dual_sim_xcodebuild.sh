#!/usr/bin/env bash
# Runs Layer C sessions in order on two simulators. Each pair is a fresh
# mailbox; Auth/Firestore persist for the emulator process, but each session
# launches with UI_TEST_RESET_AUTH so it must be self-contained.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_A="${DUAL_SIM_A:-iPhone 17 Pro}"
SIM_B="${DUAL_SIM_B:-iPhone 17}"
MAILBOX_URL="${BVT_MAILBOX_URL:-http://127.0.0.1:4739}"

run_pair() {
  local class_a="$1"
  local class_b="$2"
  echo "▶ Dual-sim pair ${class_a} / ${class_b}"
  curl -fsS -X POST "${MAILBOX_URL}/reset" >/dev/null

  env UFREE_INTEGRATION_TESTS=1 \
      BVT_MAILBOX_URL="${MAILBOX_URL}" \
      TEST_RUNNER_BVT_MAILBOX_URL="${MAILBOX_URL}" \
    xcodebuild test -project UFree.xcodeproj -scheme UFreeUITests \
    -destination "platform=iOS Simulator,name=${SIM_A}" \
    -only-testing:UFreeUITests/${class_a} &
  local pid_a=$!

  env UFREE_INTEGRATION_TESTS=1 \
      BVT_MAILBOX_URL="${MAILBOX_URL}" \
      TEST_RUNNER_BVT_MAILBOX_URL="${MAILBOX_URL}" \
    xcodebuild test -project UFree.xcodeproj -scheme UFreeUITests \
    -destination "platform=iOS Simulator,name=${SIM_B}" \
    -only-testing:UFreeUITests/${class_b} &
  local pid_b=$!

  local status_a=0
  local status_b=0
  wait "$pid_a" || status_a=$?
  wait "$pid_b" || status_b=$?
  if [ "$status_a" -ne 0 ] || [ "$status_b" -ne 0 ]; then
    echo "✖ Pair failed: ${class_a}=${status_a} ${class_b}=${status_b}" >&2
    return 1
  fi
}

run_pair BVTDualSimConnectA BVTDualSimConnectB
run_pair BVTDualSimAvailabilityA BVTDualSimAvailabilityB
run_pair BVTDualSimNudgeA BVTDualSimNudgeB
run_pair BVTDualSimDeletionA BVTDualSimDeletionB
