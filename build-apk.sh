#!/usr/bin/env bash
# Wrapper that builds a Flutter release APK and renames the output to
# CareMe.apk. Flutter's CLI hardcodes `app-release.apk` in the
# `flutter-apk/` directory, so we rename it here after the build.
#
# Usage (from repo root, in bash / Git Bash):
#   ./build-apk.sh
set -euo pipefail

cd "$(dirname "$0")"

JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" \
    flutter build apk --release

OUT_DIR="build/app/outputs/flutter-apk"
SRC="$OUT_DIR/app-release.apk"
DEST="$OUT_DIR/CareMe.apk"

if [[ ! -f "$SRC" ]]; then
    echo "Expected $SRC but it wasn't produced. Aborting rename." >&2
    exit 1
fi

mv -f "$SRC" "$DEST"
rm -f "$OUT_DIR/app-release.apk.sha1"

SIZE="$(du -h "$DEST" | cut -f1)"
echo
echo "Built: $DEST ($SIZE)"
