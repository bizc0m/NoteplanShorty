# Version 3

Working branch for NotePlan Shortcut Maker v3.

## Decision

V3 removes custom image and icon options.

## Contract

`note.md` dropped -> `Destination/note.app` -> encoded NotePlan URL.

Always:

- supports multiple notes
- never changes the `.md` file
- never creates `Name 2.app`
- no `CFBundleIconFile`
- no `CFBundleIconName`
- no `applet.icns`
- no `CustomIcon.icns`
