#!/usr/bin/env kotlin
// Prepare a droid release from the commits since the last tag.
//
//   kotlin scripts/release.main.kts                 show what the next release would be
//   kotlin scripts/release.main.kts --apply         write it: files, commit and tag
//   kotlin scripts/release.main.kts 2.0.0 --apply   a specific version
//
// Version: a breaking change (`type!:` or a `BREAKING CHANGE:` footer) bumps
// the major, a `feat` the minor, anything else the patch. Each major version
// takes the next Android dessert as its codename (1.x Cupcake, 2.x Donut, ...).
//
// --apply updates droid.toml, kshelld's Cargo.toml and Cargo.lock and
// apps/gradle.properties, adds the entry to RELEASES.md, commits
// "chore(release): droid X.Y.Z" and makes the annotated tag vX.Y.Z. It never
// pushes: check the commit, then `git push origin master vX.Y.Z`.

import java.io.File
import kotlin.system.exitProcess

val root = File(".").canonicalFile
val desserts = listOf(
    "Cupcake", "Donut", "Eclair", "Froyo", "Gingerbread", "Honeycomb", "Ice Cream Sandwich",
    "Jelly Bean", "KitKat", "Lollipop", "Marshmallow", "Nougat", "Oreo", "Pie", "Quince Tart",
    "Red Velvet Cake", "Snow Cone", "Tiramisu", "Upside Down Cake", "Vanilla Ice Cream", "Baklava",
)

fun fail(msg: String): Nothing {
    System.err.println("✘ $msg")
    exitProcess(1)
}

fun git(vararg args: String, check: Boolean = true): String {
    val p = ProcessBuilder("git", *args).directory(root).redirectErrorStream(true).start()
    val out = p.inputStream.bufferedReader().readText()
    if (p.waitFor() != 0 && check) fail("git ${args.joinToString(" ")}:\n$out")
    return out.trim()
}

data class Version(val major: Int, val minor: Int, val patch: Int) {
    override fun toString() = "$major.$minor.$patch"
    companion object {
        fun parse(s: String) = Regex("""^v?(\d+)\.(\d+)\.(\d+)$""").matchEntire(s.trim())
            ?.destructured?.let { (a, b, c) -> Version(a.toInt(), b.toInt(), c.toInt()) }
    }
}

data class Commit(val type: String, val scope: String, val breaking: Boolean, val subject: String)

val headerRe = Regex("""^(\w+)(\(([^)]*)\))?(!)?: (.+)$""")

// ── What's being released ───────────────────────────────────────────

val apply = "--apply" in args
val wanted = args.firstOrNull { !it.startsWith("--") }?.let { Version.parse(it) ?: fail("not a version: $it") }

val droidToml = File(root, "droid.toml")
val current = Regex("""(?m)^version = "([^"]+)"""").find(droidToml.readText())?.groupValues?.get(1)
    ?.let(Version::parse) ?: fail("no version in droid.toml")
val lastTag = git("describe", "--tags", "--abbrev=0", "--match", "v*", check = false).takeIf { it.startsWith("v") }
val range = if (lastTag != null) "$lastTag..HEAD" else "HEAD"

val commits = git("log", "--no-merges", "--format=%s%x00%b%x00", range).split("\u0000")
    .map { it.trim() }.chunked(2).filter { it.size == 2 && it[0].isNotEmpty() }
    .mapNotNull { (subject, body) ->
        headerRe.matchEntire(subject)?.destructured?.let { (type, _, scope, bang, text) ->
            Commit(type, scope, bang == "!" || Regex("""(?m)^BREAKING[ -]CHANGE:""").containsMatchIn(body), text)
        }
    }
    // The previous release's own commit isn't news.
    .filterNot { it.type == "chore" && it.scope == "release" }

if (commits.isEmpty() && wanted == null) fail("nothing to release since ${lastTag ?: "the start"}")

val bump = when {
    commits.any { it.breaking } -> "major"
    commits.any { it.type == "feat" } -> "minor"
    else -> "patch"
}
val base = Version.parse(lastTag ?: "") ?: current
val next = wanted ?: when (bump) {
    "major" -> Version(base.major + 1, 0, 0)
    "minor" -> Version(base.major, base.minor + 1, 0)
    else -> Version(base.major, base.minor, base.patch + 1)
}
val codename = desserts.getOrNull(next.major - 1) ?: fail("no dessert for major version ${next.major}")
val newMajor = lastTag == null || next.major != base.major

// ── The RELEASES.md entry ───────────────────────────────────────────

fun item(c: Commit) = "- " + (if (c.scope.isNotEmpty()) "**${c.scope}:** " else "") + c.subject
val sections = listOf(
    "Breaking changes" to commits.filter { it.breaking },
    "Features" to commits.filter { it.type == "feat" && !it.breaking },
    "Fixes" to commits.filter { it.type == "fix" && !it.breaking },
    "Performance" to commits.filter { it.type == "perf" && !it.breaking },
).filter { it.second.isNotEmpty() }

val entry = buildString {
    appendLine("### $next")
    appendLine()
    if (sections.isEmpty()) appendLine("Maintenance: build, docs and internal changes.\n")
    for ((title, list) in sections) {
        appendLine("#### $title")
        appendLine()
        list.forEach { appendLine(item(it)) }
        appendLine()
    }
}

println("droid $current → $next ($codename), a $bump release from ${commits.size} commits since ${lastTag ?: "the start"}\n")
println(entry)

if (!apply) {
    println("Dry run: nothing written. Run with --apply to update the files, commit and tag v$next.")
    exitProcess(0)
}

// ── Apply ───────────────────────────────────────────────────────────

if (git("status", "--porcelain", "--untracked-files=no").isNotEmpty()) fail("commit or stash your changes first")
if (git("tag", "--list", "v$next").isNotEmpty()) fail("tag v$next already exists")

// A file that's already up to date (say, the version was bumped by hand)
// is left alone.
fun File.edit(transform: (String) -> String) {
    val before = readText()
    val after = transform(before)
    if (after != before) writeText(after)
}

droidToml.edit { s ->
    s.replaceFirst(Regex("""(?m)^version = "[^"]+""""), "version = \"$next\"")
        .replaceFirst(Regex("""(?m)^codename = "[^"]+""""), "codename = \"$codename\"")
}
val daemon = File(root, "home/.config/quickshell/kshell/daemon")
File(daemon, "Cargo.toml").edit { it.replaceFirst(Regex("""(?m)^version = "[^"]+""""), "version = \"$next\"") }
File(daemon, "Cargo.lock").edit {
    it.replaceFirst(Regex("""(name = "kshelld"\nversion = )"[^"]+""""), "$1\"$next\"")
}
File(root, "apps/gradle.properties").takeIf { it.exists() }?.edit {
    it.replaceFirst(Regex("""(?m)^version=.*$"""), "version=$next")
}

File(root, "RELEASES.md").edit { s ->
    if (Regex("""(?m)^### ${Regex.escape(next.toString())}\b""").containsMatchIn(s)) return@edit s
    val majorHeading = "## ${next.major}.x $codename"
    if (newMajor || majorHeading !in s) {
        // A new major version: its own section above the previous one, with
        // its art if assets/droid_<codename>.svg exists.
        val slug = codename.lowercase().replace(" ", "_")
        val art = if (File(root, "assets/droid_$slug.svg").exists())
            "<img src=\"assets/droid_$slug.svg\" alt=\"$codename\" width=\"120\" align=\"right\">\n\n" else ""
        val at = s.indexOf("\n## ").takeIf { it >= 0 }?.plus(1) ?: s.length
        s.substring(0, at) + "$majorHeading\n\n$art$entry" + s.substring(at)
    } else {
        // Another release in this major: first under its heading (after any art).
        val head = s.indexOf(majorHeading)
        val firstEntry = s.indexOf("\n### ", head).takeIf { it >= 0 }?.plus(1) ?: (head + majorHeading.length + 2)
        s.substring(0, firstEntry) + entry + s.substring(firstEntry)
    }
}

val files = listOf("droid.toml", "RELEASES.md", "home/.config/quickshell/kshell/daemon/Cargo.toml",
    "home/.config/quickshell/kshell/daemon/Cargo.lock") +
    listOfNotNull("apps/gradle.properties".takeIf { File(root, it).exists() })
git("add", *files.toTypedArray())
// Nothing to commit when every file was already at this version.
if (git("diff", "--cached", "--name-only").isNotEmpty())
    git("commit", "-q", "-m", "chore(release): droid $next\n\nVersion $next ($codename).")
git("tag", "-a", "v$next", "-m", "droid $next ($codename)")
println("✔ Committed and tagged v$next. Check it, then: git push origin HEAD v$next")
