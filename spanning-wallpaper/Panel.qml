pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell

import qs.Commons
import qs.Widgets
import qs.Services.UI

import "./common"

Item {
    id: root
    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 1000 * Style.uiScaleRatio
    property real contentPreferredHeight: 700 * Style.uiScaleRatio


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.currentWallpaper || ""
    readonly property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder || pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""
    readonly property bool processing: pluginApi?.mainInstance?.processing || false


    /***************************
    * COMPONENTS
    ***************************/
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginL

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NText {
                    text: "Spanning Wallpaper"
                    pointSize: Style.fontSizeXL
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "x"
                    onClicked: root.pluginApi?.closePanel(root.pluginApi.panelOpenScreen);
                }
            }

            // Tool row
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    icon: "wallpaper-selector"
                    text: "Folder"
                    tooltipText: "Choose a folder that contains your spanning wallpapers."
                    onClicked: wallpapersFolderPicker.openFilePicker();
                }

                NButton {
                    icon: "dice"
                    text: "Random"
                    tooltipText: "Choose a random wallpaper and span it across all monitors."
                    enabled: !root.processing
                    onClicked: {
                        if (root.pluginApi?.mainInstance == null) {
                            Logger.e("spanning-wallpaper", "Main instance is null");
                            return;
                        }
                        root.pluginApi.mainInstance.random();
                    }
                }

                NButton {
                    icon: "clear-all"
                    text: "Clear"
                    tooltipText: "Reset wallpapers to the default."
                    onClicked: {
                        if (root.pluginApi?.mainInstance == null) {
                            Logger.e("spanning-wallpaper", "Main instance is null");
                            return;
                        }
                        root.pluginApi.mainInstance.clear();
                    }
                }

                Item { Layout.fillWidth: true }

                NLabel {
                    visible: root.processing
                    label: "Processing..."
                }
            }

            // Wallpapers grid
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Color.mSurfaceVariant
                radius: Style.radiusS

                NGridView {
                    id: gridView
                    anchors {
                        fill: parent
                        margins: Style.marginXXS
                    }

                    property int columns: Math.max(1, Math.floor(availableWidth / 300))
                    property int itemSize: Math.floor(availableWidth / columns)

                    cellWidth: itemSize
                    cellHeight: Math.floor(itemSize * (9 / 16))

                    model: folderModel.ready ? folderModel.files : 0

                    delegate: Item {
                        id: wallpaper
                        required property string modelData
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        NImageRounded {
                            id: wallpaperImage
                            anchors {
                                fill: parent
                                margins: Style.marginXXS
                            }

                            radius: Style.radiusXS

                            borderWidth: {
                                if (root.currentWallpaper === wallpaper.modelData) return Style.borderM;
                                else return 0;
                            }
                            borderColor: Color.mPrimary

                            imagePath: wallpaper.modelData
                            fallbackIcon: "alert-circle"

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent

                                acceptedButtons: Qt.LeftButton
                                cursorShape: root.processing ? Qt.BusyCursor : Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: {
                                    if (root.processing) return;
                                    if (root.pluginApi?.mainInstance == null) {
                                        Logger.e("spanning-wallpaper", "Main instance is null");
                                        return;
                                    }

                                    root.pluginApi.mainInstance.applySpanning(wallpaper.modelData);
                                }

                                onEntered: {
                                    const filename = wallpaper.modelData.split('/').pop();
                                    TooltipService.show(wallpaperImage, filename, "auto", 100);
                                }
                                onExited: TooltipService.hideImmediately();
                            }
                        }
                    }
                }
            }
        }
    }

    FolderModel {
        id: folderModel
        folder: root.wallpapersFolder
        filters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp"]
    }

    NFilePicker {
        id: wallpapersFolderPicker
        title: "Choose spanning wallpapers folder"
        initialPath: root.wallpapersFolder
        selectionMode: "folders"

        onAccepted: paths => {
            if (paths.length > 0 && root.pluginApi != null) {
                Logger.d("spanning-wallpaper", "Selected folder:", paths[0]);
                root.pluginApi.pluginSettings.wallpapersFolder = paths[0];
                root.pluginApi.saveSettings();
            }
        }
    }
}
