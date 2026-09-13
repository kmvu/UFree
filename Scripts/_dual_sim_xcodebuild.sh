#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_A="${DUAL_SIM_A:-iPhone 17 Pro}"
SIM_B="${DUAL_SIM_B:-iPhone 17}"

xcodebuild test -project UFree.xcodeproj -scheme UFreeUITests \
  -destination "platform=iOS Simulator,name=${SIM_A}" \
  -only-testing:UFreeUITests/BVTDualSimConnectA &
pid_a=$!

xcodebuild test -project UFree.xcodeproj -scheme UFreeUITests \
  -destination "platform=iOS Simulator,name=${SIM_B}" \
  -only-testing:UFreeUITests/BVTDualSimConnectB &
pid_b=$!

wait "$pid_a"
wait "$pid_b"
