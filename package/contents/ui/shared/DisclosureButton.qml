import QtQuick
import QtQuick.Controls

AbstractButton {
    id: control
    property bool expanded: false
    property bool enableMotion: true
    property string tip: ""
    implicitWidth: 26
    implicitHeight: 26
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: tip
    ToolTip.visible: (hovered || visualFocus) && tip !== ""
    ToolTip.text: tip
    ToolTip.delay: 450
    background: Rectangle {
        radius: width / 2
        color: control.down ? Theme.wash(Theme.highlightColor, .16) : control.hovered || control.visualFocus ? Theme.wash(Theme.highlightColor, .08) : "transparent"
        border.color: control.visualFocus ? Theme.highlightColor : "transparent"
    }
    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            width: 14
            height: 14
            source: Qt.resolvedUrl("../assets/ic_disclosure.svg")
            isMask: true
            color: control.hovered || control.expanded ? Theme.textColor : Theme.muted
            rotation: control.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: control.enableMotion && control.visible ? 140 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
