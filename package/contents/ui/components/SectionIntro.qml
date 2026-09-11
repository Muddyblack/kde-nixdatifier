import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// Title and explanation at the top of a section, with trailing tags or actions.
RowLayout {
    id: intro
    property string title: ""
    property string subtitle: ""
    property color textColor: UI.Theme.textColor
    property real fs: 1
    default property alias trailing: trailingRow.data
    spacing: 8
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        Text {
            Layout.fillWidth: true
            text: intro.title
            textFormat: Text.PlainText
            color: intro.textColor
            font.pixelSize: UI.Theme.fontPx(12, intro.fs)
            font.weight: Font.Medium
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            visible: intro.subtitle !== ""
            text: intro.subtitle
            textFormat: Text.PlainText
            color: "#8e9eb3"
            font.pixelSize: UI.Theme.fontPx(10, intro.fs)
            wrapMode: Text.WrapAnywhere
            lineHeight: 1.4
        }
    }
    RowLayout {
        id: trailingRow
        Layout.alignment: Qt.AlignTop
        spacing: 6
    }
}
