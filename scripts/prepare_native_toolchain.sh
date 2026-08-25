#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

if ! command -v mise >/dev/null 2>&1; then
  echo "mise is required. Install it with: brew install mise" >&2
  exit 1
fi

mise install

java_root=$(mise where java)

mise exec -- flutter config --jdk-dir="$java_root"
mise exec -- flutter pub get --enforce-lockfile

if [[ $(uname -s) == "Darwin" ]]; then
  for command_name in xcodebuild xcrun pod; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo "$command_name is required for the iOS build." >&2
      exit 1
    fi
  done

  xcode_version=$(xcodebuild -version | head -n 1)
  pod_version=$(pod --version)
  echo "Native Apple toolchain: $xcode_version, CocoaPods $pod_version"
  if [[ $xcode_version != "Xcode 26.6" || $pod_version != "1.17.0" ]]; then
    echo "WARN: validated baseline is Xcode 26.6 with CocoaPods 1.17.0." >&2
  fi

  if ! xcrun simctl list runtimes | grep -Eq '^iOS .*com\.apple\.CoreSimulator\.SimRuntime\.iOS-'; then
    echo "An iOS Simulator runtime is required. Run: xcodebuild -downloadPlatform iOS" >&2
    exit 1
  fi
fi

mise exec -- flutter doctor -v
echo "Native toolchain preparation complete."
