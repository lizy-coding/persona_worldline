#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
export PUB_HOSTED_URL=https://pub.dev
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
for pack in assets/content/*.json; do
  dart run tool/validate_pack.dart "$pack"
done
dart run tool/validate_pack.dart docs/templates/story_pack.json
