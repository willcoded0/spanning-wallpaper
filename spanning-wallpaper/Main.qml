import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

import "./common"
import "./main"

Item {
    id: root
    property var pluginApi: null


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.currentWallpaper || ""
    readonly property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder || pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""
    readonly property bool processing: spanProcessor.processing


    /***************************
    * WALLPAPER FUNCTIONALITY
    ***************************/
    function applySpanning(path: string) {
        spanProcessor.applySpanning(path);
    }

    function random() {
        if (wallpapersFolder === "") {
            Logger.e("spanning-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (rootFolderModel.count === 0) {
            Logger.e("spanning-wallpaper", "No valid image files found!");
            return;
        }

        const rand = Math.floor(Math.random() * rootFolderModel.count);
        const url = rootFolderModel.get(rand);
        applySpanning(url);
    }

    function clear() {
        if (root.pluginApi == null) return;

        // Reset to the default Noctalia wallpaper on all screens
        for (let i = 0; i < Quickshell.screens.length; i++) {
            WallpaperService.changeWallpaper(WallpaperService.defaultWallpaper, Quickshell.screens[i].name);
        }

        pluginApi.pluginSettings.currentWallpaper = "";
        pluginApi.saveSettings();
    }


    /***************************
    * COMPONENTS
    ***************************/
    SpanProcessor {
        id: spanProcessor
        pluginApi: root.pluginApi
    }

    FolderModel {
        id: rootFolderModel
        folder: root.wallpapersFolder
        filters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp"]
    }

    IPC {
        id: ipcHandler
        pluginApi: root.pluginApi
        applySpanning: root.applySpanning
        random: root.random
        clear: root.clear
    }
}
