pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Io

import qs.Commons

Item {
    id: root

    required property string folder
    property list<string> filters: []

    readonly property bool ready: internal.ready
    readonly property list<string> files: internal.files
    readonly property int count: files.length

    // Expand ~ to the home directory
    readonly property string resolvedFolder: {
        let f = root.folder;
        if (f.startsWith("~/")) {
            return Quickshell.env("HOME") + f.substring(1);
        } else if (f === "~") {
            return Quickshell.env("HOME");
        }
        return f;
    }

    function reload() {
        if (!proc.running) {
            forceReload();
        }
    }

    function forceReload() {
        internal.ready = false
        internal.files = [];
        proc.running = false;
        proc.command = ["sh", "-c", proc._command]
        proc.running = true;
    }

    function get(index: int): string {
        return files[index];
    }

    function indexOf(file: string): int {
        return files.indexOf(file);
    }

    onResolvedFolderChanged: forceReload();

    QtObject {
        id: internal
        property bool ready: false
        property list<string> files: []
    }

    Process {
        id: proc

        readonly property string _command: {
            if (root.resolvedFolder === "") return "true";
            let filters = [];
            for (const filter of root.filters) {
                filters.push(`-iname "${filter}"`);
            }
            return `find "${root.resolvedFolder}" -maxdepth 1 -type f \\( ${filters.join(" -o ")} \\) 2>/dev/null`;
        }
        running: true
        command: ["sh", "-c", `${_command}`]

        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "") {
                    internal.files.push(line);
                }
            }
        }
        onExited: {
            internal.ready = true;
        }
    }
}
