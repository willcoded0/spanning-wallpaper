import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.Compositor

Item {
    id: root
    required property var pluginApi

    readonly property string cacheDir: (Settings.cacheDir || "/tmp/") + "spanning-wallpaper/"
    property bool processing: false

    signal processingComplete(bool success)

    Component.onCompleted: {
        // Ensure cache directory exists
        mkdirProc.running = true;
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.cacheDir]
    }

    // Compute the bounding box and per-monitor crop geometry, then run magick
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

        Logger.d("spanning-wallpaper", `Bounding box: ${totalWidth}x${totalHeight} at offset (${minX}, ${minY})`);

        // Check upscaling settings
        const upscaleEnabled = root.pluginApi?.pluginSettings?.upscaleEnabled || false;
        const upscaleMethod = root.pluginApi?.pluginSettings?.upscaleMethod || "lanczos";
        const upscaleMultiplier = root.pluginApi?.pluginSettings?.upscaleMultiplier || 2;

        // Build the ImageMagick command
        // 1. Optionally upscale the source image
        // 2. Resize to fit the bounding box (preserving aspect ratio, then crop to fill)
        // 3. For each monitor, crop the appropriate region and save
        let script = "#!/bin/sh\nset -e\n";
        const srcPath = imagePath.startsWith("file://") ? imagePath.substring(7) : imagePath;
        const tmpResized = `${root.cacheDir}resized.png`;

        if (upscaleEnabled) {
            // Upscale first, then resize to bounding box
            const upW = totalWidth * upscaleMultiplier;
            const upH = totalHeight * upscaleMultiplier;
            script += `magick "${srcPath}" -filter ${upscaleMethod} -resize ${upW}x${upH}\\> "${root.cacheDir}upscaled.png"\n`;
            script += `magick "${root.cacheDir}upscaled.png" -resize ${totalWidth}x${totalHeight}^ -gravity center -extent ${totalWidth}x${totalHeight} "${tmpResized}"\n`;
            script += `rm -f "${root.cacheDir}upscaled.png"\n`;
        } else {
            // Just resize to fill bounding box
            script += `magick "${srcPath}" -resize ${totalWidth}x${totalHeight}^ -gravity center -extent ${totalWidth}x${totalHeight} "${tmpResized}"\n`;
        }

        // Crop per-monitor slices
        for (const s of screens) {
            const cropX = s.x - minX;
            const cropY = s.y - minY;
            const outPath = `${root.cacheDir}${s.name}.png`;
            script += `magick "${tmpResized}" -crop ${s.width}x${s.height}+${cropX}+${cropY} +repage "${outPath}"\n`;
        }

        script += `rm -f "${tmpResized}"\n`;

        // Write the script and execute it
        internal.screens = screens;
        internal.imagePath = imagePath;

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
            onRead: line => Logger.d("spanning-wallpaper", "magick:", line);
        }
        stderr: SplitParser {
            onRead: line => Logger.w("spanning-wallpaper", "magick stderr:", line);
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Logger.i("spanning-wallpaper", "Image processing complete, applying wallpapers");

                // Set each monitor's wallpaper to its cropped slice
                for (const s of internal.screens) {
                    const slicePath = `${root.cacheDir}${s.name}.png`;
                    Logger.d("spanning-wallpaper", `Setting wallpaper for ${s.name}: ${slicePath}`);
                    WallpaperService.changeWallpaper(slicePath, s.name);
                }

                // Save the current spanning wallpaper path
                root.pluginApi.pluginSettings.currentWallpaper = internal.imagePath;
                root.pluginApi.saveSettings();

                root.processing = false;
                root.processingComplete(true);
            } else {
                Logger.e("spanning-wallpaper", "Image processing failed with exit code:", exitCode);
                root.processing = false;
                root.processingComplete(false);
            }
        }
    }
}
