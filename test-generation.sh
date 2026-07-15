#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="/tmp/Test NotePlan Shortcut"
OUT="$ROOT/Output"
BIN="$ROOT_DIR/.build/release/NotePlanShortcutMaker"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$ROOT"
mkdir -p "$OUT"

assert_app() {
  local note_name="$1"
  local expected_url="$2"
  local expected_icon="${3:-none}"
  local app_path="$OUT/$note_name.app"

  test -d "$app_path"
  test ! -d "$OUT/$note_name 2.app"
  test "$(basename "$app_path")" = "$note_name.app"
  test "$(plutil -extract CFBundleName raw "$app_path/Contents/Info.plist")" = "$note_name"
  test "$(plutil -extract CFBundleDisplayName raw "$app_path/Contents/Info.plist")" = "$note_name"
  test "$(plutil -extract NotePlanShortcutURL raw "$app_path/Contents/Info.plist")" = "$expected_url"
  osadecompile "$app_path/Contents/Resources/Scripts/main.scpt" | grep -F "$expected_url" >/dev/null

  if [ "$expected_icon" = "CustomIcon" ]; then
    test "$(plutil -extract CFBundleIconFile raw "$app_path/Contents/Info.plist")" = "$expected_icon"
    test -f "$app_path/Contents/Resources/CustomIcon.icns"
    test "$(stat -f %z "$app_path/Contents/Resources/CustomIcon.icns")" -lt 800000
  else
    ! plutil -extract CFBundleIconFile raw "$app_path/Contents/Info.plist" >/dev/null 2>&1
    test ! -f "$app_path/Contents/Resources/applet.icns"
  fi
}

print -- "# todo suisse"
print -- "- test" > "$ROOT/TODO Suisse.md"
"$BIN" --cli-generate "$ROOT/TODO Suisse.md" "$OUT"
assert_app "TODO Suisse" "noteplan://x-callback-url/openNote?noteTitle=TODO%20Suisse"

# Re-run on the same note: must overwrite in place, never create "TODO Suisse 2.app".
"$BIN" --cli-generate "$ROOT/TODO Suisse.md" "$OUT"
assert_app "TODO Suisse" "noteplan://x-callback-url/openNote?noteTitle=TODO%20Suisse"

print -- "# ete"
print -- "- test" > "$ROOT/Été & idées.md"
"$BIN" --cli-generate "$ROOT/Été & idées.md" "$OUT"
assert_app "Été & idées" "noteplan://x-callback-url/openNote?noteTitle=%C3%89t%C3%A9%20%26%20id%C3%A9es"

print -- "# custom icon"
print -- "- test" > "$ROOT/Icon Note.md"
sips -z 1024 1024 "$ROOT_DIR/assets/logo.png" --out "$ROOT/icon-source.png" >/dev/null
"$BIN" --cli-generate "$ROOT/Icon Note.md" "$OUT" --icon "$ROOT/icon-source.png"
assert_app "Icon Note" "noteplan://x-callback-url/openNote?noteTitle=Icon%20Note" "CustomIcon"

print -- "OK: generation checks passed (real binary, --cli-generate path)"
print -- "NOTE: this exercises NotePlanShortcutGenerator.generate() exactly as drag&drop and the file picker call it."
print -- "NOTE: the AppKit drag&drop pasteboard-reading code itself is NOT exercised by this script and must be tested by a real Finder drag."
