#!/usr/bin/env bash
# Người chấm tự động. Qua = thoát 0.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
flutter pub get
flutter analyze --no-fatal-infos
flutter test
bash scripts/invariants.sh
if [ "${1:-}" = "--full" ]; then flutter build apk --debug; fi
echo "CHECK OK"
