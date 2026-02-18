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

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            root.wallpapersFolder = root.pluginApi?.pluginSettings?.wallpapersFolder || root.pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""
            root.upscaleEnabled = root.pluginApi?.pluginSettings?.upscaleEnabled || false
        }
    }


    /***************************
    * COMPONENTS
    ***************************/
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

    NToggle {
        Layout.fillWidth: true
        label: "AI Upscaling"
        description: "Use Real-ESRGAN to upscale images before spanning. Improves quality for low-resolution wallpapers at the cost of slower processing time."
        checked: root.upscaleEnabled
        onToggled: checked => {
            root.upscaleEnabled = checked;
            root.saveSettings();
        }
    }


    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.wallpapersFolder = wallpapersFolder;
        pluginApi.pluginSettings.upscaleEnabled = upscaleEnabled;
        pluginApi.saveSettings();
    }
}
