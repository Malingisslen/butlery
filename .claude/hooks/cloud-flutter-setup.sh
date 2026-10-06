#!/usr/bin/env bash
# SessionStart hook: installs the Flutter SDK CI uses, so Claude Code cloud
# sessions can run `flutter analyze` and targeted `flutter test` (including
# test/views/golden_linux, which CI compares on ubuntu with this same SDK).
# Cloud only: on a local machine Flutter is already installed and this exits.

set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

# test.yml's FLUTTER_VERSION is what the required checks run, so the SDK here
# follows it instead of carrying a second pin that could drift.
VERSION=$(sed -n "s/^  FLUTTER_VERSION: *['\"]\{0,1\}\([0-9.]*\)['\"]\{0,1\}.*/\1/p" .github/workflows/test.yml | head -1)
if [ -z "$VERSION" ]; then
  echo "cloud-flutter-setup: no FLUTTER_VERSION in .github/workflows/test.yml" >&2
  exit 1
fi

SDK_DIR="${CLOUD_FLUTTER_DIR:-/opt/flutter-$VERSION}"

if [ ! -x "$SDK_DIR/bin/flutter" ]; then
  BASE=https://storage.googleapis.com/flutter_infra_release/releases
  read -r ARCHIVE SHA < <(curl -sSfL "$BASE/releases_linux.json" | python3 -c "
import json, sys
for r in json.load(sys.stdin)['releases']:
    if r['version'] == '$VERSION' and r['channel'] == 'stable':
        print(r['archive'], r['sha256'])
        break
")
  if [ -z "${ARCHIVE:-}" ]; then
    echo "cloud-flutter-setup: Flutter $VERSION stable not in the release index" >&2
    exit 1
  fi
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  curl -sSfL -o "$TMP/flutter.tar.xz" "$BASE/$ARCHIVE"
  echo "$SHA  $TMP/flutter.tar.xz" | sha256sum -c --quiet
  tar -xJf "$TMP/flutter.tar.xz" -C "$TMP"
  rm -rf "$SDK_DIR"
  mv "$TMP/flutter" "$SDK_DIR"
fi

# The archive is a git checkout owned by another uid; flutter refuses to run
# from it without this.
git config --global --get-all safe.directory | grep -qxF "$SDK_DIR" \
  || git config --global --add safe.directory "$SDK_DIR"

export PATH="$SDK_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1
dart --disable-analytics >/dev/null 2>&1
flutter pub get >/dev/null 2>&1 || flutter pub get

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$SDK_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

echo "cloud-flutter-setup: Flutter $VERSION ready at $SDK_DIR"
