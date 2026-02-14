import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root
    required property var pluginApi
    required property var applySpanning
    required property var random
    required property var clear

    readonly property string currentWallpaper: pluginApi?.pluginSettings?.currentWallpaper || ""

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
