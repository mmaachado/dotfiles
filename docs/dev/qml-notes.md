# QML notes

Things about Quickshell and KShell that cost time to find out.

## Running and testing

- Restart with `kshell restart`. Hot reload doesn't pick up new `.qml` files.
- Try new QML in a throwaway copy: `qs -p <dir>`, never against the live
  config. A crash opens a crash-report window that has to be closed.
- With monitors in DPMS sleep, screenshots are stale or white:
  `kscreen-doctor --dpms on` first.

## Gotchas

- A `Behavior` inside a nested `QtObject` of a singleton crashes at startup;
  put animated properties on the singleton root. A `Behavior` can't animate a
  `readonly` property either.
- A file in `modules/` named like a `services/` singleton breaks loading
  ("Composite Singleton Type … is not creatable").
- An inline `component` of one file used from another is a cyclic dependency
  ("Type X unavailable"). Shared pieces go in their own files.
- A JS function named `with` (a reserved word) breaks the whole module, with
  a misleading "Type X unavailable" chain.
- `JsonAdapter` keeps a property's old value when its key is missing from the
  file, so set keys explicitly.
- Unsetting an anchor keeps the size it gave, so size items explicitly when
  anchors change. A `Loader`'s item may keep its old size too, so fill it
  with `anchors.fill: parent`.
- Drawers must drop keyboard focus when they close, or Quickshell can crash
  on exit.

## Icons

KShell resolves icons when it loads, so changing the icon theme needs a
restart. Qt treats an icon theme with an empty `Directories=` as invalid and
ignores its `Inherits`.

## Shaders

Precompile after editing: `just shaders`, or
`/usr/lib/qt6/bin/qsb --qt6 -o X.frag.qsb X.frag`.
