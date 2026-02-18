import QtQuick
import Quickshell
import Quickshell.Io
import "sha256.js" as Checksum
import qs.Commons

// Local copy of NImageCached for use within the plugin
// (NImageCached from qs.Widgets is not accessible to plugins)
Image {
    id: root

    property string imagePath: ""
    property string imageHash: ""
    property string cacheFolder: Settings.cacheDirImagesWallpapers
    property int maxCacheDimension: 384

    readonly property string cachePath: imageHash
        ? `${cacheFolder}${imageHash}@${maxCacheDimension}x${maxCacheDimension}.png`
        : ""

    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: maxCacheDimension
    sourceSize.height: maxCacheDimension
    smooth: true

    onImagePathChanged: {
        if (imagePath) {
            imageHash = Checksum.sha256(imagePath);
        } else {
            source = "";
            imageHash = "";
        }
    }

    onCachePathChanged: {
        if (imageHash && cachePath) {
            source = cachePath;
        }
    }

    onStatusChanged: {
        if (source == cachePath && status === Image.Error) {
            // Cache miss — load the original
            source = imagePath;
        } else if (source == imagePath && status === Image.Ready && imageHash && cachePath) {
            // Original loaded — save a thumbnail to disk for next time
            const grabPath = cachePath;
            if (visible && width > 0 && height > 0 && Window.window && Window.window.visible) {
                grabToImage(res => res.saveToFile(grabPath));
            }
        }
    }
}
