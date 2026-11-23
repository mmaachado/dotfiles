# Tooling

Install the tools with `./install.py packages -g dev` (just, Kotlin, Gradle,
JDK 21, shellcheck, ruff, MkDocs Material, and lefthook through uv), then the
hooks with `just hooks`.

## just

`just` lists every task. The main ones:

| Task | Does |
| --- | --- |
| `just lint` | Everything CI checks: cargo fmt + clippy, ruff, shellcheck, `zsh -n`, droid.toml and config JSON |
| `just test` | kshelld's tests |
| `just apps` | Build and test the Kotlin apps |
| `just build` | Build and install kshelld into `~/.local/bin` |
| `just shaders` | Recompile the wallpaper shaders (`shaders-check` fails if a `.qsb` is stale) |
| `just restart` / `just log` | Restart KShell / show its latest warnings and errors |
| `just docs` / `just docs-serve` | Build this portal (strict) / serve it with live reload |
| `just commit-check --range A..B` | Check commit messages |
| `just release [version] [--apply]` | Prepare a release (see [Releasing](releasing.md)) |

CI runs the same recipes, so a green `just lint` locally means a green CI.

## Git hooks

lefthook runs, on commit, the checks that the staged files touch (rustfmt,
ruff, shellcheck, `zsh -n`, the shader and manifest checks), and checks the
commit message.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org):
`type(scope)!: subject`, with types `feat`, `fix`, `docs`, `style`,
`refactor`, `perf`, `test`, `build`, `ci`, `chore` and `revert`. The subject
starts in lowercase, has no trailing period, and the header stays within 100
characters. One logical change per commit. Releases are worked out from these
messages.
