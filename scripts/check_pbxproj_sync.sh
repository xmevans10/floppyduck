#!/bin/bash
# Verify every .swift file under FloppyDuck/ is in the Xcode project (pbxproj).
# Run before pushing to catch "Cannot find X in scope" from missing file refs.

set -euo pipefail
cd "$(dirname "$0")/.."

REPO_FILES=$(find FloppyDuck -name "*.swift" -exec basename {} \; | sort -u)
PBX_FILES=$(grep 'isa = PBXFileReference.*sourcecode.swift' FloppyDuck.xcodeproj/project.pbxproj \
  | grep -oP '/\* \K[^ ]+' | sort -u)

MISSING=$(comm -23 <(echo "$REPO_FILES") <(echo "$PBX_FILES"))

if [ -n "$MISSING" ]; then
  echo "❌ Swift files in repo but NOT in pbxproj:"
  echo "$MISSING"
  exit 1
else
  echo "✅ All Swift files are in the Xcode project."
  exit 0
fi
