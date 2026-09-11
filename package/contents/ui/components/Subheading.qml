import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// Small uppercase list heading with a count, like "SYSTEM HISTORY" on the timeline.
RowLayout {
    id: heading
    property string text: ""
    property string detail: ""
    property real fs: 1
    default property alias trailing: trailingRow.data
    spacing: 8
    Text {
        Layout.fillWidth: true
        text: heading.text.toLocaleUpperCase()
        color: "#8491a4"
        font.pixelSize: UI.Theme.fontPx(9, heading.fs)
        font.letterSpacing: 1
        elide: Text.ElideRight
    }
    Text {
        visible: heading.detail !== ""
        text: heading.detail
        color: "#7f8ba0"
        font.pixelSize: UI.Theme.fontPx(10, heading.fs)
    }
    RowLayout {
        id: trailingRow
        spacing: 4
    }
}
