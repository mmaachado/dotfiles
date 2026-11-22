pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// droid's release (droid.toml's [release] table) and the versions of what it
// runs on, for Settings → About. The shell's config dir is a symlink into
// the droid repo (home/.config/quickshell/kshell), so the repo root is four
// levels above where it resolves to.
Singleton {
    id: root

    property string name: "droid"
    property string version: ""
    property string codename: ""
    property string description: ""
    property string plasma: ""
    property string quickshell: ""
    readonly property string repo: "https://github.com/mmaachado/droid"
    // The droid repo on disk, and this major version's art in it
    // (assets/droid_<codename>.svg), if there is one.
    property string repoRoot: ""
    readonly property string art: repoRoot && codename ? `${repoRoot}/assets/droid_${codename.toLowerCase()}.svg` : ""

    function value(text: string, key: string): string {
        const table = text.match(/^\[release\]\s*$([\s\S]*?)(?=^\[|$(?![\s\S]))/m);
        const m = (table ? table[1] : "").match(new RegExp(`^${key}\\s*=\\s*"([^"]*)"`, "m"));
        return m ? m[1] : "";
    }

    Process {
        running: true
        command: ["sh", "-c", 'root=$(cd "$(readlink -f "$1")/../../../.." && pwd) && echo "$root" && cat "$root/droid.toml"',
            "sh", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.repoRoot = text.split("\n")[0];
                root.name = root.value(text, "name") || "droid";
                root.version = root.value(text, "version");
                root.codename = root.value(text, "codename");
                root.description = root.value(text, "description");
            }
        }
    }

    Process {
        running: true
        command: ["plasmashell", "--version"]
        stdout: StdioCollector {
            onStreamFinished: root.plasma = text.trim().split(/\s+/).pop() ?? ""
        }
    }

    Process {
        running: true
        command: ["qs", "--version"]
        stdout: StdioCollector {
            onStreamFinished: root.quickshell = (text.match(/Quickshell\s+(\S+)/) ?? [])[1] ?? ""
        }
    }
}
