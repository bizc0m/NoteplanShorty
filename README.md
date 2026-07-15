# NotePlan Shortcut Maker

Tiny macOS app that creates `.app` shortcuts for specific NotePlan notes.
Drop one or more NotePlan `.md` files, choose an output folder, and get one shortcut app per note.

![NotePlan Shortcut Maker v3](assets/readme/noteplan-shortcut-maker-v3.png)

## What it does

- macOS only
- SwiftUI
- No backend, no account, no cloud
- Batch note drop
- Default output folder: `~/Downloads`
- Generated shortcuts have no custom icon to keep them small
- The original `.md` notes are never modified, copied, or moved

Example:

- note: `TODO Suisse.md`
- shortcut: `DESTINATION/TODO Suisse.app`
- URL: `noteplan://x-callback-url/openNote?filename=TODO%20Suisse.md`

If the note comes from NotePlan's `Notes/` folder, the app uses the full relative path.

Example:

- note: `Notes/Projects/TODO Suisse.md`
- shortcut: `DESTINATION/TODO Suisse.app`
- URL: `noteplan://x-callback-url/openNote?filename=Projects/TODO%20Suisse.md`

## Run

```bash
./build-app.sh
open "dist/NotePlan Shortcut Maker.app"
```

Install locally:

```bash
rm -rf "/Applications/NotePlan Shortcut Maker.app"
cp -R "dist/NotePlan Shortcut Maker.app" "/Applications/NotePlan Shortcut Maker.app"
open "/Applications/NotePlan Shortcut Maker.app"
```

## Use

1. Choose a destination folder, or keep `~/Downloads`.
2. Drop one or more NotePlan `.md` files.
3. Confirm replacement if a shortcut already exists.
4. Reveal the generated shortcut in Finder.

The file picker uses the same generator as drag and drop.

## Test

```bash
./test-generation.sh
```

The test checks:

- single shortcut generation
- replacement without creating `Name 2.app`
- accented filenames
- batch generation
- NotePlan relative paths via `filename=`
- no generated shortcut icon payload
