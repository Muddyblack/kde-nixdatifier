import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "shared" as UI

Dialog {
    id: confirmDialog

    // ── Required properties from parent ──────────────────────────────────────
    required property string pendingAction   // "rollback" | "delete"
    required property int pendingGenNum
    required property color accentColor
    required property color textColor
    required property real fs
    required property bool usePkexec
    required property bool showBg
    required property var bgColor

    signal confirmed(int genNum, string action)

    // Theme-aware font sizing. Legacy hardcoded sizes were tuned against a 9px base.
    readonly property int baseFontPx: (UI.Theme.smallFont.pixelSize > 0 ? UI.Theme.smallFont.pixelSize : 11)
    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * baseFontPx * fs));
    }

    title: pendingAction === "delete" ? qsTr("Delete Generation") : (pendingAction === "switch" ? qsTr("Activate Generation Now") : qsTr("Set Next Boot Generation"))

    modal: true
    anchors.centerIn: parent
    width: Math.min(360, parent.width - 32)

    background: Rectangle {
        radius: 10
        color: confirmDialog.showBg ? confirmDialog.bgColor : UI.Theme.backgroundColor
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 12
        anchors.margins: 4

        UI.Icon {
            source: confirmDialog.pendingAction === "delete" ? "edit-delete" : (confirmDialog.pendingAction === "switch" ? "media-playback-start" : "system-reboot")
            implicitWidth: 36
            implicitHeight: 36
            color: confirmDialog.pendingAction === "delete" ? "#ff5555" : confirmDialog.accentColor
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: confirmDialog.textColor
            font.pixelSize: confirmDialog.fpx(11)
            text: {
                const pw = confirmDialog.usePkexec ? qsTr("\n\nA password prompt will appear.") : "";
                if (confirmDialog.pendingAction === "delete")
                    return qsTr("Permanently delete generation %1?\n\nThis cannot be undone.%2").arg(confirmDialog.pendingGenNum).arg(pw);
                if (confirmDialog.pendingAction === "switch")
                    return qsTr("Activate generation %1 immediately?\n\nServices will be restarted to apply the new configuration. No reboot needed.%2").arg(confirmDialog.pendingGenNum).arg(pw);
                return qsTr("Boot into generation %1 on next reboot?\n\nThis updates the bootloader without changing the running session. Reboot to activate.%2").arg(confirmDialog.pendingGenNum).arg(pw);
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                Layout.fillWidth: true
                text: qsTr("Cancel")
                onClicked: confirmDialog.close()
                background: Rectangle {
                    radius: 4
                    color: parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: confirmDialog.textColor
                    font.pixelSize: confirmDialog.fpx(10)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                Layout.fillWidth: true
                text: confirmDialog.pendingAction === "delete" ? qsTr("Delete") : (confirmDialog.pendingAction === "switch" ? qsTr("Activate") : qsTr("Set Next Boot"))
                onClicked: {
                    confirmDialog.close();
                    confirmDialog.confirmed(confirmDialog.pendingGenNum, confirmDialog.pendingAction);
                }
                background: Rectangle {
                    radius: 4
                    color: confirmDialog.pendingAction === "delete" ? (parent.hovered ? Qt.rgba(1, 0.2, 0.2, 0.35) : Qt.rgba(1, 0.2, 0.2, 0.2)) : (parent.hovered ? Qt.rgba(confirmDialog.accentColor.r, confirmDialog.accentColor.g, confirmDialog.accentColor.b, 0.35) : Qt.rgba(confirmDialog.accentColor.r, confirmDialog.accentColor.g, confirmDialog.accentColor.b, 0.2))
                    border.color: confirmDialog.pendingAction === "delete" ? "#ff5555" : confirmDialog.accentColor
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: confirmDialog.textColor
                    font.pixelSize: confirmDialog.fpx(10)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
