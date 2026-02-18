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
        var f = pluginApi?.pluginSettings?.wallpapersFolder || pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || "";
        if (f.startsWith("~/")) {
            return Quickshell.env("HOME") + f.substring(1);
        }
        return f;
    }
    property bool processing: false

    // File list
    readonly property bool filesReady: folderProc.ready
    property list<string> filesList: []

    // Counter to generate unique slice paths so WallpaperService always sees a new path
    property int generation: 0

    readonly property string baseCacheDir: (Settings.cacheDir || "/tmp/") + "spanning-wallpaper"


    /***************************
    * WALLPAPER FUNCTIONALITY
    ***************************/
    function applySpanning(path) {
        if (root.processing) {
            Logger.w("spanning-wallpaper", "Still processing, please wait");
            return;
        }
        if (!path || path === "") return;

        root.processing = true;
        root.generation++;
        var gen = root.generation;

        Logger.i("spanning-wallpaper", "Applying spanning wallpaper (gen " + gen + "):", path);

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

        // Use a unique subdir per generation so WallpaperService sees a new path every time
        var sliceDir = root.baseCacheDir + "/" + gen;

        // Check upscale settings
        var upscaleEnabled = pluginApi?.pluginSettings?.upscaleEnabled || false;
        var upscaleMethod = pluginApi?.pluginSettings?.upscaleMethod || "lanczos";
        var upscaleMultiplier = pluginApi?.pluginSettings?.upscaleMultiplier || 2;

        var script = "set -e\n";

        // Clean up old generations, keep only current
        script += "rm -rf '" + root.baseCacheDir + "'/[0-9]* 2>/dev/null || true\n";
        script += "mkdir -p '" + sliceDir + "'\n";

        // Step 1: Resize source to fill the bounding box (JPG for speed)
        var tmpResized = sliceDir + "/resized.jpg";

        if (upscaleEnabled) {
            // Use high-quality filter + unsharp mask for best perceived quality
            script += "magick '" + srcPath + "' -filter " + upscaleMethod + " -resize '" + totalWidth + "x" + totalHeight + "!' -unsharp 0x1+0.5+0 -quality 95 '" + tmpResized + "'\n";
        } else {
            script += "magick '" + srcPath + "' -resize '" + totalWidth + "x" + totalHeight + "!' -quality 95 '" + tmpResized + "'\n";
        }

        // Step 2: Crop each monitor's slice in parallel for speed
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var cropX = s.x - minX;
            var cropY = s.y - minY;
            var outPath = sliceDir + "/" + s.name + ".jpg";
            script += "magick '" + tmpResized + "' -crop '" + s.width + "x" + s.height + "+" + cropX + "+" + cropY + "' +repage -quality 95 '" + outPath + "' &\n";
        }
        script += "wait\n";
        script += "rm -f '" + tmpResized + "'\n";

        // Store for onExited handler
        internal.screens = screens;
        internal.imagePath = path;
        internal.sliceDir = sliceDir;

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
        property string sliceDir: ""
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
                    var slicePath = internal.sliceDir + "/" + s.name + ".jpg";
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
        command: ["sh", "-c", "find '" + _folder + "' -maxdepth 1 -type f -iname '*.jpg' -o -type f -iname '*.jpeg' -o -type f -iname '*.png' -o -type f -iname '*.bmp' -o -type f -iname '*.webp'"]

        stdout: SplitParser {
            onRead: line => {
                var trimmed = line.trim();
                if (trimmed !== "") {
                    root.filesList.push(trimmed);
                }
            }
        }
        onExited: {
            folderProc.ready = true;
            Logger.i("spanning-wallpaper", "Found " + root.filesList.length + " images in " + root.wallpapersFolder);
            // Restore wallpaper from saved settings after scan completes
            if (root.currentWallpaper !== "") {
                Logger.i("spanning-wallpaper", "Restoring saved wallpaper:", root.currentWallpaper);
                root.applySpanning(root.currentWallpaper);
            }
        }
    }

    onWallpapersFolderChanged: {
        if (wallpapersFolder !== "") {
            root.filesList = [];
            folderProc.ready = false;
            scanProc.running = false;
            scanProc.command = ["sh", "-c", "find '" + wallpapersFolder + "' -maxdepth 1 -type f -iname '*.jpg' -o -type f -iname '*.jpeg' -o -type f -iname '*.png' -o -type f -iname '*.bmp' -o -type f -iname '*.webp'"];
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
