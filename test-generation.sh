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
  local app_path="$OUT/$note_name.app"

  test -d "$app_path"
  test ! -d "$OUT/$note_name 2.app"
  test "$(basename "$app_path")" = "$note_name.app"
  test "$(plutil -extract CFBundleName raw "$app_path/Contents/Info.plist")" = "$note_name"
  test "$(plutil -extract CFBundleDisplayName raw "$app_path/Contents/Info.plist")" = "$note_name"
  test "$(plutil -extract NotePlanShortcutURL raw "$app_path/Contents/Info.plist")" = "$expected_url"
  osadecompile "$app_path/Contents/Resources/Scripts/main.scpt" | grep -F "$expected_url" >/dev/null
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

print -- "OK: generation checks passed (real binary, --cli-generate path)"
print -- "NOTE: this exercises NotePlanShortcutGenerator.generate() exactly as drag&drop and the file picker call it."
print -- "NOTE: the AppKit drag&drop pasteboard-reading code itself is NOT exercised by this script and must be tested by a real Finder drag."
