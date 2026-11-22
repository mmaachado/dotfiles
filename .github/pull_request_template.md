## Summary

<!-- What this changes and why. -->

## Commits

<!-- One logical change per commit, Conventional Commits: type(scope): subject -->

-

## Testing

<!-- How you checked it: `kshell restart` with a clean log, the screens you tried, screenshots for UI changes. -->

## Checklist

- [ ] CI is green
- [ ] `kshell restart` loads with no new warnings or errors in the log
- [ ] Shaders changed: `.qsb` files recompiled (`/usr/lib/qt6/bin/qsb --qt6 -o X.frag.qsb X.frag`)
- [ ] kshelld changed: `kshell build` and tested with the new binary
- [ ] New settings or commands are documented in the README
