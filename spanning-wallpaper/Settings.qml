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
    property string upscaleMethod: pluginApi?.pluginSettings?.upscaleMethod || pluginApi?.manifest?.metadata?.defaultSettings?.upscaleMethod || "lanczos"
    property int upscaleMultiplier: pluginApi?.pluginSettings?.upscaleMultiplier || pluginApi?.manifest?.metadata?.defaultSettings?.upscaleMultiplier || 2


    /***************************
    * COMPONENTS
    ***************************/
    // Wallpapers Folder
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
            onTextChanged: root.wallpapersFolder = text
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
                }
            }
        }
    }

    NDivider {}

    // Upscaling toggle
    NToggle {
        Layout.fillWidth: true
        label: "Enable Upscaling"
        description: "Upscale images before spanning. Useful for lower resolution images to maintain quality across large combined screen areas."
        checked: root.upscaleEnabled
        onToggled: checked => root.upscaleEnabled = checked
    }

    // Upscale method
    NComboBox {
        enabled: root.upscaleEnabled
        Layout.fillWidth: true
        label: "Upscale Method"
        description: "The ImageMagick filter to use for upscaling."
        defaultValue: "lanczos"
        model: [
            { "key": "lanczos",  "name": "Lanczos (Best quality)" },
            { "key": "catrom",   "name": "Catrom (Sharp)" },
            { "key": "mitchell", "name": "Mitchell (Balanced)" },
            { "key": "point",    "name": "Nearest Neighbor (Pixel art)" }
        ]
        currentKey: root.upscaleMethod
        onSelected: key => root.upscaleMethod = key
    }

    // Upscale multiplier
    NComboBox {
        enabled: root.upscaleEnabled
        Layout.fillWidth: true
        label: "Upscale Multiplier"
        description: "How much to enlarge the image before fitting to the combined screen area."
        defaultValue: "2"
        model: [
            { "key": "2", "name": "2x" },
            { "key": "3", "name": "3x" },
            { "key": "4", "name": "4x" }
        ]
        currentKey: root.upscaleMultiplier.toString()
        onSelected: key => root.upscaleMultiplier = parseInt(key)
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            root.wallpapersFolder = root.pluginApi?.pluginSettings?.wallpapersFolder || root.pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""
            root.upscaleEnabled = root.pluginApi?.pluginSettings?.upscaleEnabled || false
            root.upscaleMethod = root.pluginApi?.pluginSettings?.upscaleMethod || root.pluginApi?.manifest?.metadata?.defaultSettings?.upscaleMethod || "lanczos"
            root.upscaleMultiplier = root.pluginApi?.pluginSettings?.upscaleMultiplier || root.pluginApi?.manifest?.metadata?.defaultSettings?.upscaleMultiplier || 2
        }
    }

    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if (!pluginApi) {
            Logger.e("spanning-wallpaper", "Cannot save, pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.wallpapersFolder = wallpapersFolder;
        pluginApi.pluginSettings.upscaleEnabled = upscaleEnabled;
        pluginApi.pluginSettings.upscaleMethod = upscaleMethod;
        pluginApi.pluginSettings.upscaleMultiplier = upscaleMultiplier;

        pluginApi.saveSettings();
    }
}
