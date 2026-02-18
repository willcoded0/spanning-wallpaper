import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell

import qs.Commons
import qs.Widgets
import qs.Services.UI

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
    readonly property string wallpapersFolder: pluginApi?.mainInstance?.wallpapersFolder || ""
    readonly property bool processing: pluginApi?.mainInstance?.processing || false
    readonly property bool filesReady: pluginApi?.mainInstance?.filesReady || false
    readonly property var filesList: pluginApi?.mainInstance?.filesList || []

    property string searchText: ""

    property var filteredList: {
        var list = root.filesList;
        if (!list || list.length === 0) return list;
        var search = root.searchText.toLowerCase().trim();
        if (search === "") return list;
        var result = [];
        for (var i = 0; i < list.length; i++) {
            var name = list[i].split('/').pop().toLowerCase();
            if (name.includes(search)) result.push(list[i]);
        }
        return result;
    }


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

                NLabel {
                    visible: root.processing
                    label: "Processing..."
                }

                NLabel {
                    visible: root.filesReady && !root.processing
                    label: root.filteredList.length + (root.searchText !== "" ? " / " + root.filesList.length : "") + " images"
                }

                NIconButton {
                    icon: "dice"
                    tooltipText: "Apply a random wallpaper"
                    enabled: !root.processing
                    onClicked: {
                        if (root.pluginApi?.mainInstance == null) return;
                        root.pluginApi.mainInstance.random();
                    }
                }

                NIconButton {
                    icon: "wallpaper-selector"
                    tooltipText: "Choose wallpapers folder"
                    onClicked: wallpapersFolderPicker.openFilePicker();
                }

                NIconButton {
                    icon: "clear-all"
                    tooltipText: "Reset wallpapers to default"
                    onClicked: {
                        if (root.pluginApi?.mainInstance == null) return;
                        root.pluginApi.mainInstance.clear();
                    }
                }

                NIconButton {
                    icon: "x"
                    onClicked: root.pluginApi?.closePanel(root.pluginApi.panelOpenScreen);
                }
            }

            NDivider { Layout.fillWidth: true }

            // Search bar
            NTextInput {
                Layout.fillWidth: true
                placeholderText: "Search wallpapers..."
                onTextChanged: root.searchText = text
            }

            // Wallpapers grid
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurface
                radius: Style.radiusM
                border.color: Color.mOutline
                border.width: Style.borderS

                // Loading state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !root.filesReady
                    spacing: Style.marginM

                    NBusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                    }
                    NText {
                        text: "Scanning folder..."
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeM
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.filesReady && root.filteredList.length === 0
                    spacing: Style.marginS

                    NIcon {
                        icon: root.searchText !== "" ? "search" : "folder-open"
                        pointSize: Style.fontSizeXXL
                        color: Color.mOnSurface
                        Layout.alignment: Qt.AlignHCenter
                    }
                    NText {
                        text: root.searchText !== "" ? "No matches found" : "No images found"
                        color: Color.mOnSurface
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignHCenter
                    }
                    NText {
                        text: root.searchText !== "" ? "Try a different search term" : "Put .jpg / .png / .webp files in:\n" + root.wallpapersFolder
                        color: Color.mOnSurfaceVariant
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 360
                    }
                }

                // Grid
                GridView {
                    id: gridView
                    anchors {
                        fill: parent
                        margins: Style.marginS
                    }
                    visible: root.filesReady && root.filteredList.length > 0
                    clip: true

                    property int columns: Math.max(1, Math.floor(width / 220))
                    property int itemSize: Math.floor(width / columns)
                    property int thumbHeight: Math.round(itemSize * 0.67)

                    cellWidth: itemSize
                    cellHeight: thumbHeight + Style.marginXS + Style.fontSizeXS + Style.marginM

                    model: root.filteredList

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            implicitHeight: 100
                            color: Color.mPrimary
                            opacity: parent.active ? 0.8 : 0.3
                            radius: width / 2
                            Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
                        }
                    }

                    delegate: ColumnLayout {
                        id: wallpaperItem

                        property string wallpaperPath: modelData
                        property bool isSelected: wallpaperPath === root.currentWallpaper
                        property string filename: wallpaperPath.split('/').pop()

                        width: gridView.itemSize
                        spacing: Style.marginXS

                        Rectangle {
                            id: imageContainer
                            Layout.fillWidth: true
                            Layout.preferredHeight: gridView.thumbHeight
                            color: Color.mSurfaceVariant

                            // Thumbnail — ImageCached generates a small PNG on disk
                            // so subsequent opens are instant
                            ImageCached {
                                anchors.fill: parent
                                imagePath: wallpaperItem.wallpaperPath
                            }

                            // Dim overlay (fades out on hover/select)
                            Rectangle {
                                anchors.fill: parent
                                color: Color.mSurface
                                opacity: (hoverHandler.hovered || wallpaperItem.isSelected || gridView.currentIndex === index) ? 0 : 0.25
                                Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
                            }

                            // Colored border
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: {
                                    if (wallpaperItem.isSelected) return Color.mSecondary;
                                    if (gridView.currentIndex === index) return Color.mHover;
                                    return Color.mOutline;
                                }
                                border.width: wallpaperItem.isSelected ? Math.max(2, Style.borderL * 1.5) : Style.borderS
                                Behavior on border.width { NumberAnimation { duration: Style.animationFast } }
                            }

                            // Checkmark badge on selected
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Style.marginS
                                width: 24
                                height: 24
                                radius: 12
                                color: Color.mSecondary
                                border.color: Color.mOutline
                                border.width: Style.borderS
                                visible: wallpaperItem.isSelected

                                NIcon {
                                    anchors.centerIn: parent
                                    icon: "check"
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSecondary
                                }
                            }

                            // Processing spinner over the active item
                            NBusyIndicator {
                                anchors.centerIn: parent
                                visible: root.processing && wallpaperItem.isSelected
                            }

                            HoverHandler { id: hoverHandler }

                            TapHandler {
                                onTapped: {
                                    if (root.processing) return;
                                    if (root.pluginApi?.mainInstance == null) return;
                                    gridView.currentIndex = index;
                                    root.pluginApi.mainInstance.applySpanning(wallpaperItem.wallpaperPath);
                                }
                            }
                        }

                        // Filename label
                        NText {
                            text: wallpaperItem.filename
                            color: (hoverHandler.hovered || wallpaperItem.isSelected || gridView.currentIndex === index) ? Color.mOnSurface : Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeXS
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            Layout.leftMargin: Style.marginS
                            Layout.rightMargin: Style.marginS
                        }
                    }
                }
            }
        }
    }

    NFilePicker {
        id: wallpapersFolderPicker
        title: "Choose spanning wallpapers folder"
        initialPath: root.wallpapersFolder
        selectionMode: "folders"

        onAccepted: paths => {
            if (paths.length > 0 && root.pluginApi != null) {
                root.pluginApi.pluginSettings.wallpapersFolder = paths[0];
                root.pluginApi.saveSettings();
            }
        }
    }
}
