#!/bin/bash
# Firebase Crashlytics dSYM Upload Script
# This script runs as a build phase to upload debug symbols to Firebase Crashlytics
# for readable crash reports in the Firebase console.
#
# Build Phase: Run Script
# Shell: /bin/bash
# Script:
# "${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"

set -e

FIREBASE_SDK_PATH="${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk"

if [ -f "${FIREBASE_SDK_PATH}/Crashlytics/run" ]; then
    echo "📤 Uploading dSYMs to Firebase Crashlytics..."
    "${FIREBASE_SDK_PATH}/Crashlytics/run"
    echo "✅ dSYMs uploaded successfully"
else
    echo "⚠️  Firebase Crashlytics run script not found at expected path"
    echo "Path checked: ${FIREBASE_SDK_PATH}/Crashlytics/run"
    echo "Ensure Firebase is installed via SPM and the project is built"
fi
