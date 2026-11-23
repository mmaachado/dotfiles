# Kotlin apps

droid's app windows are written in Kotlin with
[Compose Multiplatform](https://www.jetbrains.com/compose-multiplatform/) and
Material 3, so they look like Android apps. They live in `apps/`, a Gradle
(Kotlin DSL) multi-project:

| Module | What |
| --- | --- |
| `common` | `DroidTheme` (KShell's current Material colours from `~/.local/state/kshell/scheme.json`, and Google Sans) and `KShell` (IPC and settings) |
| `markup` | Screenshot editor *(coming)* |
| `phone` | Phone mirroring front end for scrcpy *(coming)* |

```sh
just apps                 # ./gradlew build in apps/: compile and test
```

The apps compile for JDK 21. Gradle downloads it if it isn't installed. The
version comes from `apps/gradle.properties`, which the release script keeps
equal to droid.toml's.

Wrap an app's UI in `DroidTheme { … }` to get droid's colours and font.

!!! note "Shell surfaces stay QML"
    Bars, overlays and drawers are Wayland layer-shell surfaces, which Compose
    can't create. Kotlin is for normal windows.
