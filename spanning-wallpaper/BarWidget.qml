import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null

    property ShellScreen screen

    implicitWidth: pill.width
    implicitHeight: pill.height


    /***************************
    * COMPONENTS
    ***************************/
    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": "Panel",
                "action": "panel",
                "icon": "rectangle"
            },
            {
                "label": "Random",
                "action": "random",
                "icon": "dice"
            },
            {
                "label": "Clear",
                "action": "clear",
                "icon": "clear-all"
            },
            {
                "label": I18n.tr("actions.widget-settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);

            switch (action) {
                case "panel":
                    root.pluginApi?.openPanel(root.screen, root);
                    break;
                case "random":
                    if (root.pluginApi?.mainInstance != null) {
                        root.pluginApi.mainInstance.random();
                    }
                    break;
                case "clear":
                    if (root.pluginApi?.mainInstance != null) {
                        root.pluginApi.mainInstance.clear();
                    }
                    break;
                case "settings":
                    BarService.openPluginSettings(root.screen, root.pluginApi.manifest);
                    break;
                default:
                    Logger.e("spanning-wallpaper", "Unknown action:", action);
            }
        }
    }

    BarPill {
        id: pill

        screen: root.screen
        tooltipText: "Open the spanning wallpaper manager."

        icon: "wallpaper-selector"

        onClicked: {
            root.pluginApi?.openPanel(root.screen, root);
        }

        onRightClicked: {
            PanelService.showContextMenu(contextMenu, root, root.screen);
        }
    }
}
