#!/usr/bin/env kotlin
// Conventional Commits check for droid.
//
//   kotlin scripts/commit-msg.main.kts <message-file>      one message (git's commit-msg hook)
//   kotlin scripts/commit-msg.main.kts --range A..B        every commit in a range (CI)
//
// A header looks like `type(scope)!: subject`: a known type, an optional
// lowercase scope, `!` for a breaking change, and a subject that starts in
// lowercase, has no trailing period and keeps the header within 100
// characters. A blank line separates the header from the body. Merge,
// revert, fixup! and squash! commits are left alone.

import java.io.File
import kotlin.system.exitProcess

val types = listOf("feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert")
val header = Regex("""^(\w+)(\(([a-z0-9][a-z0-9/,.-]*)\))?(!)?: (.+)$""")
val maxHeader = 100

fun problems(message: String): List<String> {
    // Git's own comment lines don't count.
    val lines = message.lines().filterNot { it.startsWith("#") }.dropLastWhile { it.isBlank() }
    val first = lines.firstOrNull()?.trimEnd() ?: return listOf("the message is empty")
    if (Regex("""^(Merge |Revert "|fixup! |squash! |amend! )""").containsMatchIn(first)) return emptyList()

    val m = header.matchEntire(first)
        ?: return listOf("the header should look like `type(scope): subject`, got `$first`")
    val (type, _, _, _, subject) = m.destructured
    val out = mutableListOf<String>()
    if (type !in types) out += "unknown type `$type`; use one of ${types.joinToString(", ")}"
    if (subject.first().isUpperCase()) out += "start the subject in lowercase (`${subject.replaceFirstChar { it.lowercase() }}`)"
    if (subject.endsWith(".")) out += "drop the period at the end of the subject"
    if (first.length > maxHeader) out += "keep the header within $maxHeader characters (it has ${first.length})"
    if (lines.size > 1 && lines[1].isNotBlank()) out += "leave a blank line between the header and the body"
    return out
}

fun git(vararg args: String): String {
    val p = ProcessBuilder("git", *args).redirectErrorStream(true).start()
    val out = p.inputStream.bufferedReader().readText()
    if (p.waitFor() != 0) {
        System.err.println("git ${args.joinToString(" ")} failed:\n$out")
        exitProcess(2)
    }
    return out
}

val bad = when {
    args.size == 2 && args[0] == "--range" -> {
        // NUL-separated: hash, then the full message.
        git("log", "--format=%H%x00%B%x00", args[1]).split("\u0000")
            .map { it.trim() }.chunked(2).filter { it.size == 2 && it[0].isNotEmpty() }
            .mapNotNull { (hash, msg) -> problems(msg).takeIf { it.isNotEmpty() }?.let { "${hash.take(8)} ${msg.lineSequence().first()}" to it } }
    }
    args.size == 1 -> problems(File(args[0]).readText()).takeIf { it.isNotEmpty() }?.let { listOf("commit message" to it) } ?: emptyList()
    else -> {
        System.err.println("usage: commit-msg.main.kts <message-file> | --range A..B")
        exitProcess(2)
    }
}

for ((what, list) in bad) {
    System.err.println("✘ $what")
    list.forEach { System.err.println("    - $it") }
}
if (bad.isNotEmpty()) {
    System.err.println("\nSee https://www.conventionalcommits.org and the types above.")
    exitProcess(1)
}
