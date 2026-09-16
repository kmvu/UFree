#!/usr/bin/env bash
# Runs Layer C sessions in order on two simulators. Each pair is a fresh
# mailbox; Auth/Firestore persist for the emulator process, but each session
# launches with UI_TEST_RESET_AUTH so it must be self-contained.
#
# Build once, then test-without-building in parallel. Two `xcodebuild test`
# processes sharing default DerivedData serialize: B starts, waits for readyA,
# and times out while A is still compiling.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_A="${DUAL_SIM_A:-iPhone 17 Pro}"
SIM_B="${DUAL_SIM_B:-iPhone 17}"
MAILBOX_URL="${BVT_MAILBOX_URL:-http://127.0.0.1:4739}"
CACHE="${UFree_BVT_CACHE:-$HOME/Library/Caches/UFreeBVT}"
DD="${DUAL_SIM_DERIVED_DATA:-$CACHE/derived}"
RESULT_DIR="${DUAL_SIM_RESULT_DIR:-$CACHE/results}"
mkdir -p "$DD" "$RESULT_DIR"

destination_for() {
  local spec="$1"
  if [[ "$spec" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
    printf 'platform=iOS Simulator,id=%s\n' "$spec"
    return
  fi
  local udid=""
  udid="$(DUAL_SIM_NAME="$spec" python3 - <<'PY'
import json, os, subprocess, sys
name = os.environ["DUAL_SIM_NAME"]
data = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "-j"]
))
matches = []
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("name") == name:
            matches.append(device)
if not matches:
    sys.exit(1)
booted = [d for d in matches if d.get("state") == "Booted"]
print((booted or matches)[0]["udid"])
PY
)" || udid=""
  if [[ -n "$udid" ]]; then
    printf 'platform=iOS Simulator,id=%s\n' "$udid"
  else
    printf 'platform=iOS Simulator,name=%s\n' "$spec"
  fi
}

DEST_A="$(destination_for "$SIM_A")"
DEST_B="$(destination_for "$SIM_B")"
echo "▶ Destinations: A=${DEST_A}  B=${DEST_B}"
if [[ "$DEST_A" == "$DEST_B" ]]; then
  echo "✖ A and B resolved to the same simulator. Set DUAL_SIM_A / DUAL_SIM_B to UDIDs." >&2
  exit 1
fi

echo "▶ Building UFreeUITests once → ${DD}"
xcodebuild build-for-testing -project UFree.xcodeproj -scheme UFreeUITests \
  -destination "$DEST_A" \
  -derivedDataPath "$DD"

run_xcode() {
  local dest="$1"
  local class="$2"
  env UFREE_INTEGRATION_TESTS=1 \
      BVT_MAILBOX_URL="${MAILBOX_URL}" \
      TEST_RUNNER_BVT_MAILBOX_URL="${MAILBOX_URL}" \
    xcodebuild test-without-building -project UFree.xcodeproj -scheme UFreeUITests \
      -destination "$dest" \
      -derivedDataPath "$DD" \
      -resultBundlePath "${RESULT_DIR}/${class}.xcresult" \
      -collect-test-diagnostics never \
      -only-testing:UFreeUITests/${class}
}

clear_emulators() {
  # phoneDirectory is first-writer-wins. Session 1 claims +15550000001/02;
  # session 2's new UIDs must not look up the previous pair.
  curl -fsS -X DELETE \
    "http://127.0.0.1:8080/emulator/v1/projects/ufree-313a2/databases/(default)/documents" >/dev/null
  curl -fsS -X DELETE \
    "http://127.0.0.1:9099/emulator/v1/projects/ufree-313a2/accounts" >/dev/null
}

run_pair() {
  local class_a="$1"
  local class_b="$2"
  echo "▶ Dual-sim pair ${class_a} / ${class_b}"
  rm -rf "${RESULT_DIR}/${class_a}.xcresult" "${RESULT_DIR}/${class_b}.xcresult" 2>/dev/null || true
  # A poisoned /tmp bundle from a prior SIP/diagnostics failure cannot be overwritten.
  if [[ -e "${RESULT_DIR}/${class_a}.xcresult" || -e "${RESULT_DIR}/${class_b}.xcresult" ]]; then
    RESULT_DIR="${RESULT_DIR}/run-$$"
    mkdir -p "$RESULT_DIR"
    echo "▶ Result dir ${RESULT_DIR} (previous bundle was not removable)"
  fi
  curl -fsS -X POST "${MAILBOX_URL}/reset" >/dev/null
  clear_emulators

  run_xcode "$DEST_A" "$class_a" &
  local pid_a=$!
  run_xcode "$DEST_B" "$class_b" &
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

case "${DUAL_SIM_ONLY:-all}" in
  connect) run_pair BVTDualSimConnectA BVTDualSimConnectB ;;
  availability) run_pair BVTDualSimAvailabilityA BVTDualSimAvailabilityB ;;
  nudge) run_pair BVTDualSimNudgeA BVTDualSimNudgeB ;;
  deletion) run_pair BVTDualSimDeletionA BVTDualSimDeletionB ;;
  all)
    run_pair BVTDualSimConnectA BVTDualSimConnectB
    run_pair BVTDualSimAvailabilityA BVTDualSimAvailabilityB
    run_pair BVTDualSimNudgeA BVTDualSimNudgeB
    run_pair BVTDualSimDeletionA BVTDualSimDeletionB
    ;;
  *)
    echo "✖ Unknown DUAL_SIM_ONLY=${DUAL_SIM_ONLY} (connect|availability|nudge|deletion|all)" >&2
    exit 1
    ;;
esac
