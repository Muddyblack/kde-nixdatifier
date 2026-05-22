import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami

Item {
    id: compactRoot

    implicitWidth: Kirigami.Units.gridUnit * 2.2
    implicitHeight: Kirigami.Units.gridUnit * 2.2

    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    // ── Required properties from root ────────────────────────────────────────
    required property color accentColor
    required property color textColor
    required property int activeGenNum
    required property var flakeUpdates
    required property bool isBusy
    required property bool isLoadingGens
    required property string compactStyle
    required property bool compactShowBadge
    required property string iconStyle

    readonly property bool logoIsMask: iconStyle !== "colored"
    readonly property bool logoUseImage: iconStyle === "colored"
    readonly property color logoColor: {
        if (iconStyle === "white") {
            return "#ffffff";
        }
        if (iconStyle === "black") {
            return "#000000";
        }
        return compactRoot.accentColor;
    }

    signal toggleExpanded

    MouseArea {
        id: compactMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        z: 10
        onClicked: compactRoot.toggleExpanded()
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 5
        color: compactMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    Kirigami.Icon {
        id: compactIconImage
        visible: compactRoot.compactStyle !== "number" && compactRoot.logoUseImage
        source: Qt.resolvedUrl("nixos-logo.svg")
        isMask: false
        anchors.centerIn: parent
        implicitWidth: compactRoot.compactStyle === "both" ? parent.width * 0.55 : parent.width - 10
        implicitHeight: implicitWidth
        anchors.verticalCenterOffset: compactRoot.compactStyle === "both" ? -4 : 0
    }

    Kirigami.Icon {
        id: compactIcon
        visible: compactRoot.compactStyle !== "number" && !compactRoot.logoUseImage
        source: Qt.resolvedUrl("nixos-logo.svg")
        isMask: true
        color: compactRoot.logoColor
        anchors.centerIn: parent
        implicitWidth: compactRoot.compactStyle === "both" ? parent.width * 0.55 : parent.width - 10
        implicitHeight: implicitWidth
        anchors.verticalCenterOffset: compactRoot.compactStyle === "both" ? -4 : 0
        Behavior on color {
            ColorAnimation {
                duration: 300
            }
        }
    }

    Text {
        visible: compactRoot.compactStyle !== "icon" && compactRoot.activeGenNum > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: compactRoot.compactStyle === "both" ? 3 : 0
        anchors.verticalCenter: compactRoot.compactStyle === "number" ? parent.verticalCenter : undefined
        text: compactRoot.activeGenNum > 0 ? compactRoot.activeGenNum : "—"
        color: compactRoot.textColor
        font.pixelSize: compactRoot.compactStyle === "both" ? Math.round(Kirigami.Theme.smallFont.pixelSize * 0.85) : Math.round(Kirigami.Theme.smallFont.pixelSize * 1.15)
        font.bold: true
    }

    Rectangle {
        visible: compactRoot.compactShowBadge && compactRoot.flakeUpdates.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 3
        anchors.rightMargin: 3
        width: 14
        height: 14
        radius: 7
        color: "#cc88ff"
        border.color: Kirigami.Theme.backgroundColor
        border.width: 1.5

        Text {
            anchors.centerIn: parent
            text: compactRoot.flakeUpdates.length
            color: "#ffffff"
            font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.85)
            font.bold: true
        }
    }

    Kirigami.Icon {
        id: compactSpinnerImage
        anchors.centerIn: parent
        visible: (compactRoot.isBusy || compactRoot.isLoadingGens) && compactRoot.logoUseImage
        source: Qt.resolvedUrl("nixos-logo.svg")
        isMask: false
        implicitWidth: parent.width - 6
        implicitHeight: parent.height - 6
        RotationAnimation on rotation {
            running: compactSpinnerImage.visible
            from: 0
            to: 360
            duration: 1400
            loops: Animation.Infinite
        }
    }

    Kirigami.Icon {
        id: compactSpinner
        anchors.centerIn: parent
        visible: (compactRoot.isBusy || compactRoot.isLoadingGens) && !compactRoot.logoUseImage
        source: Qt.resolvedUrl("nixos-logo.svg")
        isMask: true
        color: compactRoot.logoColor
        width: parent.width - 6
        height: parent.height - 6
        RotationAnimation on rotation {
            running: compactSpinner.visible
            from: 0
            to: 360
            duration: 1400
            loops: Animation.Infinite
        }
    }
}
