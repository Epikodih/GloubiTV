#!/usr/bin/env bash
# Installe l'environnement de dev (macOS, Linux) : Flutter à la version de la
# CI (fixée dans .fvmrc, installée par fvm dans .fvm/), Rust, et sous macOS
# CocoaPods et Xcode pour l'app TV. Relançable sans risque.
#
#   just setup        (ou : ./scripts/setup-dev.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/.*"flutter": *"\([^"]*\)".*/\1/p' .fvmrc)
echo "==> Flutter $version (fvm)"
if ! command -v fvm >/dev/null; then
  if command -v brew >/dev/null; then
    brew tap leoafarias/fvm && brew install fvm
  elif command -v dart >/dev/null; then
    dart pub global activate fvm
    export PATH="$PATH:$HOME/.pub-cache/bin"
  else
    echo "Installe fvm : https://fvm.app/documentation/getting-started/installation" >&2
    exit 1
  fi
fi
# Télécharge la version si besoin et crée .fvm/flutter_sdk (utilisé par just).
fvm use "$version" --force
.fvm/flutter_sdk/bin/flutter --version | head -1

echo "==> Rust"
if ! command -v cargo >/dev/null; then
  echo "Installe Rust : https://rustup.rs" >&2
  exit 1
fi
cargo --version

if [ "$(uname)" = Darwin ]; then
  echo "==> macOS : CocoaPods et Xcode (app TV)"
  command -v pod >/dev/null || brew install cocoapods
  if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    echo "À lancer une fois (mot de passe demandé) : sudo xcodebuild -runFirstLaunch"
  fi
fi

echo "==> Prêt : just core, puis just tv <macos|linux|windows>"
