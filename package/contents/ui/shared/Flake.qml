import QtQuick

Icon {
    id: flake
    property bool working: false
    property bool motion: true
    property string style: "colored"
    property color accent: Theme.highlightColor
    source: Qt.resolvedUrl("../../../icon-emblem.svg")
    isMask: style !== "colored"
    color: style === "white" ? "white" : style === "black" ? "black" : accent
    RotationAnimation on rotation {
        running: flake.working && flake.visible && flake.motion
        from: 0
        to: 360
        duration: 1800
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            flake.rotation = 0
    }
}
