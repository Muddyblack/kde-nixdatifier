pragma Singleton
import QtQuick

QtObject {
    property color textColor: "#e6ecf5"
    property color systemTextColor: "#e6ecf5"
    property color systemBackgroundColor: "#131923"
    property color backgroundColor: "#131923"
    property color highlightColor: "#91bcff"
    readonly property color muted: "#939fb2"
    readonly property color positive: "#6ee7b7"
    readonly property color negative: "#fb858f"
    readonly property color changed: "#f2cc70"
    readonly property color line: "#12ffffff"
    property font smallFont: Qt.font({
        family: Qt.application.font.family,
        pixelSize: 11
    })
    property font defaultFont: Qt.font({
        family: Qt.application.font.family,
        pixelSize: 13
    })
    property font fixedWidthFont: Qt.font({
        family: "monospace",
        pixelSize: 11
    })
    property Component iconDelegate: null
    property var iconResolver: function (name) {
        return "";
    }
    function luminance(value) {
        const c = Qt.color(value);
        const linear = v => v <= .04045 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4);
        return .2126 * linear(c.r) + .7152 * linear(c.g) + .0722 * linear(c.b);
    }
    function contrast(a, b) {
        const x = luminance(a), y = luminance(b);
        return (Math.max(x, y) + .05) / (Math.min(x, y) + .05);
    }
    function textOn(surface, preferred) {
        if (contrast(surface, preferred) >= 4.5)
            return preferred;
        return contrast(surface, textColor) >= 4.5 ? textColor : "#17202d";
    }
    function wash(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }
}
