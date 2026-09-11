import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property string glyph: ""
    property color accent: Theme.highlightColor
    property bool primary: false
    property bool flatStyle: false
    property color foreground: primary ? accent : Theme.textOn(palette.window, palette.text)
    property string tip: text
    font.pixelSize: 10
    implicitHeight: 29
    implicitWidth: text === "" ? implicitHeight : contentItem.implicitWidth + 20
    padding: 6
    hoverEnabled: true
    Accessible.name: text || tip
    ToolTip.visible: (hovered || activeFocus) && tip !== ""
    ToolTip.text: tip
    ToolTip.delay: 450
    background: Rectangle {
        radius: 6
        color: control.down ? Theme.wash(control.accent, .16) : control.hovered ? "#0cffffff" : control.flatStyle ? "transparent" : control.primary ? Theme.wash(control.accent, .09) : "#04ffffff"
        border.color: control.activeFocus ? control.accent : control.flatStyle ? "transparent" : control.primary ? Theme.wash(control.accent, .24) : "#14ffffff"
        opacity: control.enabled ? 1 : .45
    }
    contentItem: RowLayout {
        spacing: 6
        Icon {
            visible: control.glyph !== ""
            source: control.glyph
            isMask: true
            color: control.primary ? control.accent : Theme.muted
            implicitWidth: control.flatStyle && control.text === "" ? 16 : 13
            implicitHeight: implicitWidth
            opacity: control.enabled ? 1 : .45
        }
        Text {
            visible: text !== ""
            text: control.text
            color: control.foreground
            font: control.font
            opacity: control.enabled ? 1 : .45
        }
    }
}
