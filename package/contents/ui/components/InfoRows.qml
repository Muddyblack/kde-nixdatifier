import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// Label/value pairs in a card, like the Nix store card on the Tools page.
// rows: [{ label, value, tone? }]
Rectangle {
    id: info
    property var rows: []
    property color textColor: UI.Theme.textColor
    property real fs: 1
    implicitHeight: column.implicitHeight + 24
    radius: 9
    color: "#03ffffff"
    border.color: "#0effffff"
    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        Repeater {
            model: info.rows
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: modelData.label
                    color: "#8fa0b7"
                    font.pixelSize: UI.Theme.fontPx(9, info.fs)
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData.value
                    textFormat: Text.PlainText
                    color: modelData.tone || info.textColor
                    font.pixelSize: UI.Theme.fontPx(9, info.fs)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
