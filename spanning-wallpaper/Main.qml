import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.currentWallpaper || ""
    readonly property string wallpapersFolder: {
        let f = pluginApi?.pluginSettings?.wallpapersFolder || pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || "";
        if (f.startsWith("~/")) {
            return Quickshell.env("HOME") + f.substring(1);
        }
        return f;
    }
    property bool processing: false

    // File list
    readonly property bool filesReady: folderProc.ready
    property list<string> filesList: []


    /***************************
    * WALLPAPER FUNCTIONALITY
    ***************************/
    function applySpanning(path) {
        if (root.processing) return;
        if (!path || path === "") return;

        root.processing = true;
        Logger.i("spanning-wallpaper", "Applying spanning wallpaper:", path);

        var screens = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var s = Quickshell.screens[i];
            screens.push({
                name: s.name,
                x: s.x,
                y: s.y,
                width: s.width,
                height: s.height
            });
        }

        if (screens.length === 0) {
            Logger.e("spanning-wallpaper", "No screens found");
            root.processing = false;
            return;
        }

        // Compute bounding box
        var minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (s.x < minX) minX = s.x;
            if (s.y < minY) minY = s.y;
            if (s.x + s.width > maxX) maxX = s.x + s.width;
            if (s.y + s.height > maxY) maxY = s.y + s.height;
        }

        var totalWidth = maxX - minX;
        var totalHeight = maxY - minY;

        Logger.i("spanning-wallpaper", "Bounding box: " + totalWidth + "x" + totalHeight + ", screens: " + screens.length);

        var srcPath = path.startsWith("file://") ? path.substring(7) : path;
        var cacheDir = (Settings.cacheDir || "/tmp/") + "spanning-wallpaper";

        // Build shell script
        var upscaleEnabled = pluginApi?.pluginSettings?.upscaleEnabled || false;
        var upscaleMethod = pluginApi?.pluginSettings?.upscaleMethod || "lanczos";
        var upscaleMultiplier = pluginApi?.pluginSettings?.upscaleMultiplier || 2;

        var script = "set -e\nmkdir -p '" + cacheDir + "'\n";
        var tmpResized = cacheDir + "/resized.png";

        if (upscaleEnabled) {
            var upW = totalWidth * upscaleMultiplier;
            var upH = totalHeight * upscaleMultiplier;
            script += "magick '" + srcPath + "' -filter " + upscaleMethod + " -resize '" + upW + "x" + upH + ">' '" + cacheDir + "/upscaled.png'\n";
            script += "magick '" + cacheDir + "/upscaled.png' -resize '" + totalWidth + "x" + totalHeight + "^' -gravity center -extent '" + totalWidth + "x" + totalHeight + "' '" + tmpResized + "'\n";
            script += "rm -f '" + cacheDir + "/upscaled.png'\n";
        } else {
            script += "magick '" + srcPath + "' -resize '" + totalWidth + "x" + totalHeight + "^' -gravity center -extent '" + totalWidth + "x" + totalHeight + "' '" + tmpResized + "'\n";
        }

        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var cropX = s.x - minX;
            var cropY = s.y - minY;
            var outPath = cacheDir + "/" + s.name + ".png";
            script += "magick '" + tmpResized + "' -crop '" + s.width + "x" + s.height + "+" + cropX + "+" + cropY + "' +repage '" + outPath + "'\n";
        }
        script += "rm -f '" + tmpResized + "'\n";

        // Store for onExited handler
        internal.screens = screens;
        internal.imagePath = path;
        internal.cacheDir = cacheDir;

        magickProc.command = ["sh", "-c", script];
        magickProc.running = true;
    }

    function random() {
        if (root.wallpapersFolder === "") {
            Logger.e("spanning-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (root.filesList.length === 0) {
            Logger.e("spanning-wallpaper", "No image files found! Folder: " + root.wallpapersFolder);
            return;
        }

        var rand = Math.floor(Math.random() * root.filesList.length);
        var url = root.filesList[rand];
        Logger.i("spanning-wallpaper", "Random picked: " + url);
        applySpanning(url);
    }

    function clear() {
        if (root.pluginApi == null) return;

        for (var i = 0; i < Quickshell.screens.length; i++) {
            WallpaperService.changeWallpaper(WallpaperService.defaultWallpaper, Quickshell.screens[i].name);
        }

        pluginApi.pluginSettings.currentWallpaper = "";
        pluginApi.saveSettings();
    }


    /***************************
    * INTERNALS
    ***************************/
    QtObject {
        id: internal
        property var screens: []
        property string imagePath: ""
        property string cacheDir: ""
    }

    // Image processing
    Process {
        id: magickProc

        stderr: SplitParser {
            onRead: line => Logger.w("spanning-wallpaper", "magick: " + line);
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Logger.i("spanning-wallpaper", "Processing complete, setting wallpapers");

                for (var i = 0; i < internal.screens.length; i++) {
                    var s = internal.screens[i];
                    var slicePath = internal.cacheDir + "/" + s.name + ".png";
                    Logger.i("spanning-wallpaper", "Setting " + s.name + " -> " + slicePath);
                    WallpaperService.changeWallpaper(slicePath, s.name);
                }

                root.pluginApi.pluginSettings.currentWallpaper = internal.imagePath;
                root.pluginApi.saveSettings();
            } else {
                Logger.e("spanning-wallpaper", "magick failed with exit code: " + exitCode);
            }
            root.processing = false;
        }
    }

    // File scanning
    QtObject {
        id: folderProc
        property bool ready: false
    }

    Process {
        id: scanProc

        property string _folder: root.wallpapersFolder

        running: _folder !== ""
        command: ["sh", "-c", "find '" + _folder + "' -maxdepth 1 -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.webp'"]

        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "") {
                    root.filesList.push(line);
                }
            }
        }
        onExited: {
            folderProc.ready = true;
            Logger.i("spanning-wallpaper", "Found " + root.filesList.length + " images in " + root.wallpapersFolder);
        }
    }

    onWallpapersFolderChanged: {
        if (wallpapersFolder !== "") {
            root.filesList = [];
            folderProc.ready = false;
            scanProc.running = false;
            scanProc.command = ["sh", "-c", "find '" + wallpapersFolder + "' -maxdepth 1 -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.webp'"];
            scanProc.running = true;
        }
    }

    // IPC Handler
    IpcHandler {
        target: "plugin:spanningwallpaper"

        function setWallpaper(path: string) {
            root.applySpanning(path);
        }
        function getWallpaper(): string {
            return root.currentWallpaper;
        }
        function random() {
            root.random();
        }
        function clear() {
            root.clear();
        }
        function openPanel() {
            root.pluginApi.withCurrentScreen(screen => {
                root.pluginApi.openPanel(screen);
            });
        }
    }
}
