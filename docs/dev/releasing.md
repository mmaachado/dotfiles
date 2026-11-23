# Releasing

Each **major** version takes the next Android dessert as its codename: 1.x is
Cupcake, 2.x Donut, then Eclair, Froyo, and so on. Minor and patch releases
keep the codename.

```sh
just release              # dry run: the next version and its RELEASES.md entry
just release --apply      # write it, commit and tag
git push origin master v1.2.0
```

The version comes from the commits since the last tag: a breaking change
(`feat!:` or a `BREAKING CHANGE:` footer) bumps the major and the codename,
a `feat` the minor, anything else the patch. Pass a version to override it:
`just release 2.0.0 --apply`.

`--apply` updates `droid.toml`, kshelld's `Cargo.toml` and `Cargo.lock` and
`apps/gradle.properties`, adds the RELEASES.md entry (a new section for a new
codename), commits `chore(release): droid X.Y.Z` and creates the annotated
tag `vX.Y.Z`. It doesn't push. Pushing the tag runs the release workflow,
which publishes "droid X.Y.Z (Codename)" on GitHub.

For a new codename, add its art as `assets/droid_<codename>.svg`. The README,
RELEASES.md and Settings → About pick it up.
