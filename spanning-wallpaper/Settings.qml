import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    spacing: Style.marginM


    /***************************
    * PROPERTIES
    ***************************/
    property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder || pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""
    property bool upscaleEnabled: pluginApi?.pluginSettings?.upscaleEnabled || false
    property bool autoEnabled: pluginApi?.pluginSettings?.autoEnabled || false
    property int autoIntervalSec: pluginApi?.pluginSettings?.autoIntervalSec || 300

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            root.wallpapersFolder = root.pluginApi?.pluginSettings?.wallpapersFolder || root.pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""
            root.upscaleEnabled = root.pluginApi?.pluginSettings?.upscaleEnabled || false
            root.autoEnabled = root.pluginApi?.pluginSettings?.autoEnabled || false
            root.autoIntervalSec = root.pluginApi?.pluginSettings?.autoIntervalSec || 300
        }
    }


    /***************************
    * COMPONENTS
    ***************************/

    // --- Wallpapers Folder ---
    NLabel {
        label: "Wallpapers Folder"
        description: "The folder containing images to span across all monitors."
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NTextInput {
            Layout.fillWidth: true
            placeholderText: "/path/to/folder/with/wallpapers"
            text: root.wallpapersFolder
            onTextChanged: {
                root.wallpapersFolder = text;
                root.saveSettings();
            }
        }

        NIconButton {
            icon: "wallpaper-selector"
            tooltipText: "Select wallpapers folder"
            onClicked: folderPicker.openFilePicker()
        }

        NFilePicker {
            id: folderPicker
            title: "Choose spanning wallpapers folder"
            initialPath: root.wallpapersFolder
            selectionMode: "folders"

            onAccepted: paths => {
                if (paths.length > 0) {
                    root.wallpapersFolder = paths[0];
                    root.saveSettings();
                }
            }
        }
    }

    NDivider {}

    // --- AI Upscaling ---
    NToggle {
        Layout.fillWidth: true
        label: "AI Upscaling"
        description: "Use Real-ESRGAN to upscale images before spanning. Improves quality for low-resolution wallpapers at the cost of slower processing (~15-30s)."
        checked: root.upscaleEnabled
        onToggled: checked => {
            root.upscaleEnabled = checked;
            root.saveSettings();
        }
    }

    NDivider {}

    // --- Auto Wallpaper Switching ---
    NToggle {
        Layout.fillWidth: true
        label: "Auto Wallpaper Switching"
        description: "Automatically cycle to a random spanning wallpaper at the set interval."
        checked: root.autoEnabled
        onToggled: checked => {
            root.autoEnabled = checked;
            root.saveSettings();
        }
    }

    // Interval presets (only visible when auto is enabled)
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.autoEnabled
        spacing: Style.marginS

        NLabel {
            label: "Switch Interval"
            description: "How often to automatically switch to a new random wallpaper."
        }

        NComboBox {
            Layout.fillWidth: true
            label: "Interval"
            defaultValue: "300"
            model: [
                { "key": "60",   "name": "1 minute" },
                { "key": "300",  "name": "5 minutes" },
                { "key": "600",  "name": "10 minutes" },
                { "key": "1800", "name": "30 minutes" },
                { "key": "3600", "name": "1 hour" }
            ]
            currentKey: root.autoIntervalSec.toString()
            onSelected: key => {
                root.autoIntervalSec = parseInt(key);
                root.saveSettings();
            }
        }
    }


    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.wallpapersFolder = wallpapersFolder;
        pluginApi.pluginSettings.upscaleEnabled = upscaleEnabled;
        pluginApi.pluginSettings.autoEnabled = autoEnabled;
        pluginApi.pluginSettings.autoIntervalSec = autoIntervalSec;
        pluginApi.saveSettings();
    }
}
