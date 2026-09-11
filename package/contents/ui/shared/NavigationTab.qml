import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
    id: tab
    property string glyph: ""
    property bool selected: false
    property int count: -1
    property color accent: Theme.highlightColor
    property real scaleFactor: 1
    property bool showIcon: true
    implicitWidth: labelRow.implicitWidth + 2
    implicitHeight: 42 * scaleFactor
    padding: 0
    hoverEnabled: true
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.description: selected ? qsTr("Selected") : ""
    background: Rectangle {
        color: tab.hovered ? "#04ffffff" : "transparent"
        Rectangle {
            objectName: "selectionUnderline"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            radius: 1
            visible: tab.selected
            color: tab.accent
        }
    }
    contentItem: RowLayout {
        id: labelRow
        spacing: 6
        Icon {
            visible: tab.showIcon
            source: tab.glyph
            isMask: true
            color: tab.selected ? tab.accent : Theme.muted
            implicitWidth: 14
            implicitHeight: 14
        }
        Text {
            text: tab.text
            color: tab.selected ? tab.accent : Theme.muted
            font.pixelSize: 11 * tab.scaleFactor
        }
        Rectangle {
            visible: tab.count >= 0
            implicitWidth: badge.implicitWidth + 9
            implicitHeight: 15 * tab.scaleFactor
            radius: 4
            color: Theme.wash(tab.accent, .12)
            Text {
                id: badge
                anchors.centerIn: parent
                text: tab.count
                color: tab.accent
                font.pixelSize: 9 * tab.scaleFactor
            }
        }
    }
}
