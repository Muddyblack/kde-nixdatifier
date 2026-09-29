import QtQuick
import QtQuick.Controls.Basic as QQC

QQC.TextField {
    id: control
    implicitHeight: 34
    leftPadding: 10
    rightPadding: 10
    selectByMouse: true
    color: "#eeefeb"
    placeholderTextColor: "#787f82"
    selectionColor: "#91bcff"
    selectedTextColor: "#101b2c"
    font.pixelSize: 12
    background: Rectangle {
        radius: 8
        color: "#0f1112"
        border.color: control.activeFocus ? "#91bcff" : control.hovered ? "#33ffffff" : "#1cffffff"
    }
}
