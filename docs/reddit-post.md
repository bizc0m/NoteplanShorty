# Reddit post draft

Title:

```text
I made a tiny macOS app to create NotePlan note shortcuts
```

Post:

```text
Hi everyone,

I made a very small macOS utility for my own NotePlan workflow and thought it might be useful to someone else.

It creates `.app` shortcuts from NotePlan `.md` files. You drop one or more notes, choose a destination folder, and it generates one shortcut app per note. Opening the shortcut opens the matching NotePlan note directly.

I kept it intentionally simple:

- macOS only
- no account, no backend, no cloud
- batch drag and drop
- generated shortcuts stay small
- the original notes are not modified, copied, or moved

The current version uses NotePlan's `filename=` callback parameter with the relative path inside the Notes folder, so it should work correctly with notes inside folders.

It's not a polished product, just a small helper app. Feedback is welcome, especially if there is a simpler or more reliable way to handle NotePlan callbacks.

GitHub:
https://github.com/bizc0m/NoteplanShorty
```
