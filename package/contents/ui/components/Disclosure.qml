import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as UI

ColumnLayout {
    id: root
    property string title: ""
    property bool expanded: false
    default property alias contents: content.data
    UI.ActionButton {
        Layout.fillWidth: true
        text: (root.expanded ? "▾ " : "▸ ") + root.title
        onClicked: root.expanded = !root.expanded
    }
    ScrollView {
        visible: root.expanded
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(180, content.implicitHeight)
        clip: true
        Column {
            id: content
            width: parent.width
        }
    }
}
