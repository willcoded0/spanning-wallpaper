import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root
    required property var pluginApi

    readonly property string cacheDir: (Settings.cacheDir || "/tmp/") + "spanning-wallpaper/"
    property bool processing: false

    signal processingComplete(bool success)

    Component.onCompleted: {
        mkdirProc.running = true;
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.cacheDir]
    }

    function shellEscape(s: string): string {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function applySpanning(imagePath: string) {
        if (root.processing) {
            Logger.w("spanning-wallpaper", "Already processing, ignoring request");
            return;
        }

        if (!imagePath || imagePath === "") {
            Logger.e("spanning-wallpaper", "No image path provided");
            return;
        }

        root.processing = true;
        Logger.i("spanning-wallpaper", "Starting spanning wallpaper process for:", imagePath);

        const screens = [];
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const s = Quickshell.screens[i];
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

        // Compute bounding box of all monitors
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const s of screens) {
            minX = Math.min(minX, s.x);
            minY = Math.min(minY, s.y);
            maxX = Math.max(maxX, s.x + s.width);
            maxY = Math.max(maxY, s.y + s.height);
        }

        const totalWidth = maxX - minX;
        const totalHeight = maxY - minY;

        Logger.i("spanning-wallpaper", `Bounding box: ${totalWidth}x${totalHeight}, monitors: ${screens.length}`);

        const upscaleEnabled = root.pluginApi?.pluginSettings?.upscaleEnabled || false;
        const upscaleMethod = root.pluginApi?.pluginSettings?.upscaleMethod || "lanczos";
        const upscaleMultiplier = root.pluginApi?.pluginSettings?.upscaleMultiplier || 2;

        // Build shell script with properly escaped paths
        const srcPath = imagePath.startsWith("file://") ? imagePath.substring(7) : imagePath;
        const escapedSrc = shellEscape(srcPath);
        const tmpResized = shellEscape(`${root.cacheDir}resized.png`);

        let script = "set -e\n";

        if (upscaleEnabled) {
            const upW = totalWidth * upscaleMultiplier;
            const upH = totalHeight * upscaleMultiplier;
            const escapedUpscaled = shellEscape(`${root.cacheDir}upscaled.png`);
            script += `magick ${escapedSrc} -filter ${upscaleMethod} -resize '${upW}x${upH}>' ${escapedUpscaled}\n`;
            script += `magick ${escapedUpscaled} -resize '${totalWidth}x${totalHeight}^' -gravity center -extent '${totalWidth}x${totalHeight}' ${tmpResized}\n`;
            script += `rm -f ${escapedUpscaled}\n`;
        } else {
            script += `magick ${escapedSrc} -resize '${totalWidth}x${totalHeight}^' -gravity center -extent '${totalWidth}x${totalHeight}' ${tmpResized}\n`;
        }

        // Crop per-monitor slices
        for (const s of screens) {
            const cropX = s.x - minX;
            const cropY = s.y - minY;
            const outPath = shellEscape(`${root.cacheDir}${s.name}.png`);
            script += `magick ${tmpResized} -crop '${s.width}x${s.height}+${cropX}+${cropY}' +repage ${outPath}\n`;
        }

        script += `rm -f ${tmpResized}\n`;

        internal.screens = screens;
        internal.imagePath = imagePath;

        Logger.d("spanning-wallpaper", "Running processing script");
        scriptProc.command = ["sh", "-c", script];
        scriptProc.running = true;
    }

    QtObject {
        id: internal
        property var screens: []
        property string imagePath: ""
    }

    Process {
        id: scriptProc

        stdout: SplitParser {
            onRead: line => Logger.d("spanning-wallpaper", "stdout:", line);
        }
        stderr: SplitParser {
            onRead: line => Logger.w("spanning-wallpaper", "stderr:", line);
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Logger.i("spanning-wallpaper", "Processing complete, applying wallpapers");

                for (const s of internal.screens) {
                    const slicePath = `${root.cacheDir}${s.name}.png`;
                    Logger.d("spanning-wallpaper", `Setting wallpaper for ${s.name}: ${slicePath}`);
                    WallpaperService.changeWallpaper(slicePath, s.name);
                }

                root.pluginApi.pluginSettings.currentWallpaper = internal.imagePath;
                root.pluginApi.saveSettings();

                root.processing = false;
                root.processingComplete(true);
            } else {
                Logger.e("spanning-wallpaper", "Processing failed with exit code:", exitCode);
                root.processing = false;
                root.processingComplete(false);
            }
        }
    }
}
