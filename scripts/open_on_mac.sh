#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[1/2] Ensuring VeriRx SQLite content pack is built..."
if [ ! -f "ios/VeriRx/Resources/verirx_pack.sqlite" ]; then
  npm --prefix rxforge install
  npm --prefix rxforge run seed:all
fi

echo "[2/2] Generating Xcode project via XcodeGen..."
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing xcodegen via Homebrew..."
  brew install xcodegen
fi

cd ios
xcodegen generate
echo "✓ Opening VeriRx.xcodeproj in Xcode..."
open VeriRx.xcodeproj
