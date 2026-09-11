import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "shared" as UI

Item {
    id: historyTab

    // ── Required properties ───────────────────────────────────────────────────
    required property color accentColor
    required property color textColor
    required property real fs
    required property var actionHistory
    property bool isLoadingHistory: false
    required property string activeViewMode

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }
    function fpx(n) {
        return UI.Theme.fontPx(n, fs);
    }
    function formatTimestamp(iso) {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "d MMM, hh:mm");
    }

    signal clearHistoryRequested
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "history"

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── Header ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: qsTr("%n recorded run(s)", "", historyTab.actionHistory.length)
                color: historyTab.textColor
                opacity: 0.55
                font.pixelSize: historyTab.fpx(9)
            }

            UI.ActionButton {
                text: qsTr("Clear history")
                glyph: historyTab.svg("ic_delete")
                flatStyle: true
                font.pixelSize: historyTab.fpx(9)
                enabled: historyTab.actionHistory.length > 0
                onClicked: historyTab.clearHistoryRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Empty state ──────────────────────────────────────────
        Text {
            visible: !historyTab.isLoadingHistory && historyTab.actionHistory.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 24
            text: qsTr("No rebuild history yet.\nSwitches, rollbacks, deletions, GC runs and flake updates will show up here.")
            color: historyTab.textColor
            opacity: 0.38
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: historyTab.fpx(9)
        }

        // ── Entry list ────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: historyList.implicitHeight
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: historyList
                width: parent.width
                spacing: 6

                Repeater {
                    model: historyTab.actionHistory

                    Rectangle {
                        id: entryDelegate
                        required property var modelData
                        property bool expanded: false
                        readonly property bool hasOutput: (modelData.output || "").length > 0

                        Layout.fillWidth: true
                        implicitHeight: entryContent.implicitHeight + 20
                        radius: 6
                        color: "#04ffffff"
                        border.color: modelData.success ? Qt.rgba(0.2, 0.8, 0.3, 0.22) : Qt.rgba(1, 0.2, 0.2, 0.28)
                        border.width: 1

                        ColumnLayout {
                            id: entryContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 10
                            }
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                UI.Icon {
                                    source: entryDelegate.modelData.success ? historyTab.svg("ic_check") : historyTab.svg("ic_warning")
                                    isMask: true
                                    implicitWidth: 13
                                    implicitHeight: 13
                                    color: entryDelegate.modelData.success ? "#55cc55" : "#ff8855"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: entryDelegate.modelData.label || entryDelegate.modelData.action
                                    textFormat: Text.PlainText
                                    color: historyTab.textColor
                                    font.pixelSize: historyTab.fpx(10)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: historyTab.formatTimestamp(entryDelegate.modelData.timestamp)
                                    color: historyTab.textColor
                                    opacity: 0.45
                                    font.pixelSize: historyTab.fpx(8)
                                }

                                ToolButton {
                                    visible: entryDelegate.hasOutput
                                    icon.name: entryDelegate.expanded ? "go-up" : "go-down"
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    onClicked: entryDelegate.expanded = !entryDelegate.expanded
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: entryDelegate.expanded && entryDelegate.hasOutput
                                implicitHeight: outputRow.implicitHeight + 12
                                radius: 4
                                color: Qt.rgba(0, 0, 0, 0.22)
                                border.color: Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1

                                RowLayout {
                                    id: outputRow
                                    anchors {
                                        fill: parent
                                        margins: 6
                                    }
                                    spacing: 6

                                    TextEdit {
                                        id: outputEdit
                                        Layout.fillWidth: true
                                        readOnly: true
                                        selectByMouse: true
                                        wrapMode: Text.WrapAnywhere
                                        text: entryDelegate.modelData.output || ""
                                        font.family: UI.Theme.fixedWidthFont.family
                                        font.pixelSize: historyTab.fpx(8)
                                        color: historyTab.textColor
                                        opacity: 0.85
                                        selectionColor: Qt.rgba(historyTab.accentColor.r, historyTab.accentColor.g, historyTab.accentColor.b, 0.35)
                                    }

                                    ToolButton {
                                        icon.name: "edit-copy"
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        Layout.alignment: Qt.AlignTop
                                        ToolTip.text: qsTr("Copy output")
                                        ToolTip.visible: hovered
                                        ToolTip.delay: 400
                                        onClicked: historyTab.copyToClipboard(entryDelegate.modelData.output || "")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
