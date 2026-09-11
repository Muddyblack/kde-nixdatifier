import QtQuick
import QtQuick.Effects

Item {
    id: icon
    property string source: ""
    property bool isMask: false
    property color color: Theme.textColor
    readonly property var fallbackIcons: ({
            "window-pin": "ic_pin",
            "view-refresh": "ic_refresh",
            "utilities-terminal": "ic_terminal",
            "package-x-generic": "ic_package_added",
            "go-up-right": "ic_external",
            "go-previous": "ic_back",
            "edit-find": "ic_search",
            "configure": "ic_settings",
            "view-history": "ic_history",
            "view-grid": "ic_grid",
            "drive-harddisk": "ic_disk",
            "user-identity": "ic_user",
            "clock": "ic_clock",
            "view-calendar": "ic_calendar",
            "dialog-warning": "ic_warning"
        })
    readonly property string fallbackSource: fallbackIcons[source] ? Qt.resolvedUrl("../assets/" + fallbackIcons[source] + ".svg").toString() : ""
    implicitWidth: 18
    implicitHeight: 18
    Loader {
        id: native
        anchors.fill: parent
        active: Theme.iconDelegate !== null && icon.source.indexOf("/") < 0 && !icon.fallbackSource
        sourceComponent: Theme.iconDelegate
        onLoaded: {
            item.source = Qt.binding(function () {
                return icon.source;
            });
            item.isMask = Qt.binding(function () {
                return icon.isMask;
            });
            item.color = Qt.binding(function () {
                return icon.color;
            });
        }
    }
    Image {
        id: bitmap
        anchors.fill: parent
        source: native.active ? "" : icon.source.indexOf("/") >= 0 ? icon.source : (icon.fallbackSource || Theme.iconResolver(icon.source))
        sourceSize.width: Math.max(1, icon.width * 2)
        sourceSize.height: Math.max(1, icon.height * 2)
        fillMode: Image.PreserveAspectFit
        visible: !native.active && (!icon.isMask || GraphicsInfo.api === GraphicsInfo.Software)
    }
    MultiEffect {
        anchors.fill: bitmap
        source: bitmap
        visible: !native.active && icon.isMask && GraphicsInfo.api !== GraphicsInfo.Software
        colorization: 1
        colorizationColor: icon.color
    }
}
