import QtQuick
import "../shared" as UI

// Small status pill, e.g. "3 secrets" or "Missing".
Rectangle {
    id: tag
    property string text: ""
    property color tone: "#9ba8bc"
    property real fs: 1
    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 6
    radius: 4
    color: UI.Theme.wash(tone, .1)
    Text {
        id: label
        anchors.centerIn: parent
        text: tag.text
        textFormat: Text.PlainText
        color: tag.tone
        font.pixelSize: UI.Theme.fontPx(9, tag.fs)
    }
}
