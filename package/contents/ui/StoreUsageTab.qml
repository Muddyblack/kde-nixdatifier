import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "shared" as UI

Item {
    id: storeUsageTab

    // ── Required properties ───────────────────────────────────────────────────
    required property color accentColor
    required property color textColor
    required property real fs
    required property var storeUsageResult
    property bool isProbingStoreUsage: false
    required property string activeViewMode

    function fpx(n) {
        return UI.Theme.fontPx(n, fs);
    }

    signal storeUsageRequested(string path)
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "storeusage"

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── Placeholder hint ──────────────────────────────────────
        Text {
            Layout.fillWidth: true
            text: qsTr("/nix/store/abc123...-some-package")
            color: storeUsageTab.textColor
            opacity: 0.35
            font.pixelSize: storeUsageTab.fpx(8)
            font.italic: true
            wrapMode: Text.Wrap
        }

        // ── Input field ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: pathField
                Layout.fillWidth: true
                implicitHeight: 28
                font.pixelSize: storeUsageTab.fpx(9)
                font.family: UI.Theme.fixedWidthFont.family
                placeholderText: qsTr("Enter a store path…")
                leftPadding: 8
                rightPadding: 8
                color: storeUsageTab.textColor
                onAccepted: inspectButton.clicked()
                background: Rectangle {
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: pathField.activeFocus ? Qt.rgba(storeUsageTab.accentColor.r, storeUsageTab.accentColor.g, storeUsageTab.accentColor.b, 0.6) : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }
            }

            Button {
                id: inspectButton
                text: storeUsageTab.isProbingStoreUsage ? qsTr("Inspecting…") : qsTr("Inspect")
                implicitHeight: 28
                enabled: pathField.text.trim() !== "" && !storeUsageTab.isProbingStoreUsage
                font.pixelSize: storeUsageTab.fpx(9)
                font.bold: true
                onClicked: storeUsageTab.storeUsageRequested(pathField.text.trim())
                background: Rectangle {
                    radius: 4
                    color: parent.enabled ? (parent.hovered ? Qt.rgba(storeUsageTab.accentColor.r, storeUsageTab.accentColor.g, storeUsageTab.accentColor.b, 0.30) : Qt.rgba(storeUsageTab.accentColor.r, storeUsageTab.accentColor.g, storeUsageTab.accentColor.b, 0.16)) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: parent.enabled ? storeUsageTab.accentColor : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Results ─────────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: resultsColumn.implicitHeight
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: resultsColumn
                width: parent.width
                spacing: 12

                Text {
                    visible: !storeUsageTab.storeUsageResult
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    text: qsTr("Paste a store path above to see why it is (or isn't) kept alive.")
                    color: storeUsageTab.textColor
                    opacity: 0.38
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: storeUsageTab.fpx(9)
                }

                Text {
                    visible: !!storeUsageTab.storeUsageResult && storeUsageTab.storeUsageResult.isError
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    text: storeUsageTab.storeUsageResult ? (storeUsageTab.storeUsageResult.value || "") : ""
                    color: "#ff7777"
                    wrapMode: Text.Wrap
                    font.pixelSize: storeUsageTab.fpx(9)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !!storeUsageTab.storeUsageResult && !storeUsageTab.storeUsageResult.isError
                    spacing: 12

                    Text {
                        visible: !!storeUsageTab.storeUsageResult && !storeUsageTab.storeUsageResult.exists
                        Layout.fillWidth: true
                        text: qsTr("This path no longer exists on disk.")
                        color: "#ffaa44"
                        wrapMode: Text.Wrap
                        font.pixelSize: storeUsageTab.fpx(9)
                    }

                    Text {
                        visible: !!storeUsageTab.storeUsageResult && storeUsageTab.storeUsageResult.exists && storeUsageTab.storeUsageResult.closureBytes > 0
                        Layout.fillWidth: true
                        text: qsTr("Closure size: %1").arg(UI.Theme.formatBytes(storeUsageTab.storeUsageResult ? storeUsageTab.storeUsageResult.closureBytes : 0))
                        color: storeUsageTab.textColor
                        opacity: 0.6
                        font.pixelSize: storeUsageTab.fpx(9)
                    }

                    // ── GC roots ──────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: !!storeUsageTab.storeUsageResult && storeUsageTab.storeUsageResult.exists
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: storeUsageTab.storeUsageResult && storeUsageTab.storeUsageResult.roots.length > 0 ? qsTr("Kept alive by %1 GC root(s):").arg(storeUsageTab.storeUsageResult.roots.length) : qsTr("No GC roots found — eligible for collection.")
                                color: storeUsageTab.storeUsageResult && storeUsageTab.storeUsageResult.roots.length > 0 ? storeUsageTab.textColor : "#55cc55"
                                font.pixelSize: storeUsageTab.fpx(9)
                                font.bold: true
                                wrapMode: Text.Wrap
                            }
                            ToolButton {
                                visible: !!storeUsageTab.storeUsageResult && storeUsageTab.storeUsageResult.roots.length > 0
                                icon.name: "edit-copy"
                                implicitWidth: 22
                                implicitHeight: 22
                                ToolTip.text: qsTr("Copy roots")
                                ToolTip.visible: hovered
                                ToolTip.delay: 400
                                onClicked: storeUsageTab.copyToClipboard(storeUsageTab.storeUsageResult.roots.join("\n"))
                            }
                        }

                        Repeater {
                            model: storeUsageTab.storeUsageResult ? storeUsageTab.storeUsageResult.roots : []
                            Text {
                                required property string modelData
                                Layout.fillWidth: true
                                text: modelData
                                textFormat: Text.PlainText
                                color: storeUsageTab.textColor
                                opacity: 0.75
                                font.family: UI.Theme.fixedWidthFont.family
                                font.pixelSize: storeUsageTab.fpx(8)
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }

                    // ── Referrers ─────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: !!storeUsageTab.storeUsageResult && storeUsageTab.storeUsageResult.exists && storeUsageTab.storeUsageResult.referrers.length > 0
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Referenced by %1 path(s):").arg(storeUsageTab.storeUsageResult ? storeUsageTab.storeUsageResult.referrers.length : 0)
                                color: storeUsageTab.textColor
                                opacity: 0.7
                                font.pixelSize: storeUsageTab.fpx(9)
                                font.bold: true
                            }
                            ToolButton {
                                icon.name: "edit-copy"
                                implicitWidth: 22
                                implicitHeight: 22
                                ToolTip.text: qsTr("Copy referrers")
                                ToolTip.visible: hovered
                                ToolTip.delay: 400
                                onClicked: storeUsageTab.copyToClipboard(storeUsageTab.storeUsageResult.referrers.join("\n"))
                            }
                        }

                        Repeater {
                            model: storeUsageTab.storeUsageResult ? storeUsageTab.storeUsageResult.referrers : []
                            Text {
                                required property string modelData
                                Layout.fillWidth: true
                                text: modelData
                                textFormat: Text.PlainText
                                color: storeUsageTab.textColor
                                opacity: 0.65
                                font.family: UI.Theme.fixedWidthFont.family
                                font.pixelSize: storeUsageTab.fpx(8)
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
            }
        }
    }
}
