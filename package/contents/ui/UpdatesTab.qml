import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: updatesTab

    // ── Required properties ───────────────────────────────────────────────────
    // See FullView.uiActive — false while the popup is closed.
    property bool uiActive: true
    required property color accentColor
    required property color textColor
    required property real fs
    required property bool isCheckingFlake
    required property var flakeUpdates
    required property string lastFlakeCheckTime
    required property var dryRunCache
    required property bool isDryRunning
    required property string iconStyle
    required property string activeViewMode

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }
    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * Kirigami.Theme.smallFont.pixelSize * fs));
    }

    signal dryRunRequested(string inputName, string overrideRef)
    signal dryRunCacheCleared(string inputName)
    signal updateInputRequested(string inputName)

    anchors.fill: parent
    visible: activeViewMode === "updates"

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Kirigami.Icon {
                source: updatesTab.svg("ic_updates")
                isMask: true
                implicitWidth: 18
                implicitHeight: 18
                color: "#cc88ff"
            }
            Text {
                text: updatesTab.isCheckingFlake ? i18n("Checking flake updates…") : (updatesTab.flakeUpdates.length > 0 ? (updatesTab.flakeUpdates.length === 1 ? i18n("1 flake update available") : i18n("%1 flake updates available").arg(updatesTab.flakeUpdates.length)) : (updatesTab.lastFlakeCheckTime !== "" ? i18n("All inputs up-to-date · %1").arg(updatesTab.lastFlakeCheckTime) : i18n("Flake up-to-date")))
                color: updatesTab.flakeUpdates.length > 0 ? "#cc88ff" : Qt.rgba(updatesTab.textColor.r, updatesTab.textColor.g, updatesTab.textColor.b, 0.5)
                font.pixelSize: updatesTab.fpx(11)
                font.bold: true
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                id: updateSpinner
                source: Qt.resolvedUrl("nixos-logo.svg")
                isMask: updatesTab.iconStyle !== "colored"
                color: {
                    if (updatesTab.iconStyle === "white")
                        return "#ffffff";
                    if (updatesTab.iconStyle === "black")
                        return "#000000";
                    return updatesTab.accentColor;
                }
                visible: updatesTab.isCheckingFlake
                implicitWidth: 18
                implicitHeight: 18
                RotationAnimation on rotation {
                    running: updateSpinner.visible && updatesTab.uiActive
                    from: 0
                    to: 360
                    duration: 1400
                    loops: Animation.Infinite
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: updatesTab.flakeUpdates
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Text {
                anchors.centerIn: parent
                visible: updatesTab.flakeUpdates.length === 0 && !updatesTab.isCheckingFlake
                text: i18n("No pending flake updates")
                color: updatesTab.textColor
                font.pixelSize: updatesTab.fpx(10)
                opacity: 0.35
            }

            delegate: ColumnLayout {
                width: parent ? parent.width : 0
                spacing: 0

                // ── Main row ──────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: rowMa.containsMouse ? Qt.rgba(0.7, 0.4, 1, 0.10) : Qt.rgba(0.7, 0.4, 1, 0.05)
                    border.color: Qt.rgba(0.7, 0.4, 1, 0.22)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        readonly property bool isSafeUrl: !!modelData.url && /^https?:\/\//i.test(modelData.url)
                        cursorShape: isSafeUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (isSafeUrl)
                            Qt.openUrlExternally(modelData.url)
                        ToolTip.text: modelData.url || ""
                        ToolTip.visible: containsMouse && isSafeUrl
                        ToolTip.delay: 500
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            leftMargin: 1
                            topMargin: 1
                            bottomMargin: 1
                        }
                        width: 3
                        radius: 1
                        color: "#cc88ff"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10

                        Kirigami.Icon {
                            source: updatesTab.svg("ic_package_added")
                            isMask: true
                            implicitWidth: 16
                            implicitHeight: 16
                            color: "#cc88ff"
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.input
                                color: updatesTab.textColor
                                font.pixelSize: updatesTab.fpx(11)
                                font.bold: true
                            }
                            RowLayout {
                                spacing: 6
                                Text {
                                    text: modelData.oldRev
                                    color: updatesTab.textColor
                                    font.pixelSize: updatesTab.fpx(8)
                                    opacity: 0.5
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                                Text {
                                    text: "→"
                                    color: "#cc88ff"
                                    font.pixelSize: updatesTab.fpx(8)
                                }
                                Text {
                                    text: modelData.newRev
                                    color: "#cc88ff"
                                    font.pixelSize: updatesTab.fpx(8)
                                    font.bold: true
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                                Text {
                                    visible: modelData.oldDate !== ""
                                    text: "·  " + modelData.oldDate
                                    color: updatesTab.textColor
                                    font.pixelSize: updatesTab.fpx(8)
                                    opacity: 0.4
                                }
                            }
                        }

                        // ── "Preview changes" button ──────────────
                        Rectangle {
                            id: previewBtn
                            visible: !!modelData.overrideRef
                            readonly property var drEntry: updatesTab.dryRunCache[modelData.input] || null
                            readonly property bool isLoading: drEntry && drEntry.status === "loading"
                            readonly property bool isDone: drEntry && drEntry.status === "ok"
                            readonly property bool isError: drEntry && drEntry.status === "error"
                            readonly property bool isExpanded: isDone || isError

                            width: 22
                            height: 22
                            radius: 5
                            color: previewMa.containsMouse ? Qt.rgba(0.7, 0.4, 1, 0.30) : Qt.rgba(0.7, 0.4, 1, 0.12)
                            border.color: Qt.rgba(0.7, 0.4, 1, isExpanded ? 0.70 : 0.45)
                            border.width: 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: previewBtn.isLoading ? updatesTab.svg("ic_refresh") : updatesTab.svg("ic_diff")
                                isMask: true
                                implicitWidth: 12
                                implicitHeight: 12
                                color: "#cc88ff"
                                RotationAnimation on rotation {
                                    running: previewBtn.isLoading && updatesTab.uiActive
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }
                            }

                            MouseArea {
                                id: previewMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !previewBtn.isLoading && !updatesTab.isDryRunning
                                onClicked: {
                                    // Toggle: if already expanded clear the cache entry so it collapses
                                    if (previewBtn.isExpanded) {
                                        updatesTab.dryRunCacheCleared(modelData.input);
                                    } else {
                                        updatesTab.dryRunRequested(modelData.input, modelData.overrideRef);
                                    }
                                }
                                ToolTip.text: previewBtn.isExpanded ? i18n("Hide preview") : (previewBtn.isLoading ? i18n("Evaluating… (this may take a moment)") : i18n("Preview packages that would change"))
                                ToolTip.visible: containsMouse
                                ToolTip.delay: 400
                            }
                        }

                        // ── "Update this input" button ────────────
                        Rectangle {
                            id: updateBtn
                            width: 22
                            height: 22
                            radius: 5
                            color: updateMa.containsMouse ? Qt.rgba(0.2, 0.8, 0.4, 0.30) : Qt.rgba(0.2, 0.8, 0.4, 0.12)
                            border.color: Qt.rgba(0.2, 0.8, 0.4, 0.45)
                            border.width: 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: updatesTab.svg("ic_refresh")
                                isMask: true
                                implicitWidth: 12
                                implicitHeight: 12
                                color: "#55cc88"
                            }

                            MouseArea {
                                id: updateMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: updatesTab.updateInputRequested(modelData.input)
                                ToolTip.text: i18n("Update only '%1' in lock file").arg(modelData.input)
                                ToolTip.visible: containsMouse
                                ToolTip.delay: 400
                            }
                        }

                        Text {
                            visible: !!(modelData.url)
                            text: "↗"
                            color: "#cc88ff"
                            opacity: rowMa.containsMouse ? 0.95 : 0.55
                            font.pixelSize: updatesTab.fpx(13)
                            font.bold: true
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                    }
                }

                // ── Expanded dry-run results ───────────────────────
                Rectangle {
                    id: drPanel
                    property var drEntry: updatesTab.dryRunCache[modelData.input] || null
                    property bool show: drEntry && (drEntry.status === "ok" || drEntry.status === "error")
                    property var pkgs: (drEntry && drEntry.packages) ? drEntry.packages : []
                    property bool hasError: drEntry && drEntry.status === "error"
                    property bool isEmpty: drEntry && drEntry.status === "ok" && pkgs.length === 0

                    // Row height must stay in sync with the delegate's fixed height below.
                    readonly property int rowH: 20
                    // Cap visible rows at 8 so the ListView can virtualize anything beyond that.
                    readonly property int listH: Math.min(pkgs.length * rowH, 8 * rowH)

                    Layout.fillWidth: true
                    visible: show
                    height: show ? (hasError || isEmpty ? 36 : listH + 16) : 0
                    radius: 6
                    color: Qt.rgba(0.7, 0.4, 1, 0.05)
                    border.color: Qt.rgba(0.7, 0.4, 1, 0.15)
                    border.width: 1
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Error state
                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        visible: drPanel.hasError
                        text: "⚠  " + (drPanel.drEntry ? (drPanel.drEntry.errorMsg || i18n("Evaluation failed")) : "")
                        color: "#ff6666"
                        font.pixelSize: updatesTab.fpx(8.5)
                        wrapMode: Text.WordWrap
                    }

                    // Empty / up-to-date state
                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        visible: drPanel.isEmpty
                        text: i18n("No package changes — everything is already up to date.")
                        color: updatesTab.textColor
                        opacity: 0.5
                        font.pixelSize: updatesTab.fpx(8.5)
                    }

                    // Package list — virtualized ListView replaces the old Repeater so only
                    // visible rows are instantiated, avoiding a main-thread freeze on large lists.
                    ListView {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        height: drPanel.listH
                        visible: !drPanel.hasError && !drPanel.isEmpty
                        model: drPanel.pkgs
                        clip: true
                        spacing: 3
                        cacheBuffer: drPanel.rowH * 2
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: RowLayout {
                            width: ListView.view.width
                            height: drPanel.rowH
                            spacing: 6

                            // Build/fetch badge
                            Rectangle {
                                width: 32
                                height: 13
                                radius: 3
                                color: modelData.action === "build" ? Qt.rgba(1, 0.6, 0.2, 0.18) : Qt.rgba(0.3, 0.8, 0.5, 0.14)
                                border.color: modelData.action === "build" ? Qt.rgba(1, 0.6, 0.2, 0.45) : Qt.rgba(0.3, 0.8, 0.5, 0.40)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.action === "build" ? "build" : "dl"
                                    color: modelData.action === "build" ? "#ffaa44" : "#55cc88"
                                    font.pixelSize: updatesTab.fpx(6.5)
                                    font.bold: true
                                }
                            }

                            Text {
                                text: modelData.name
                                color: updatesTab.textColor
                                font.pixelSize: updatesTab.fpx(9)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Version change
                            RowLayout {
                                spacing: 4
                                Text {
                                    visible: modelData.oldVersion !== ""
                                    text: modelData.oldVersion
                                    color: updatesTab.textColor
                                    opacity: 0.45
                                    font.pixelSize: updatesTab.fpx(8)
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                                Text {
                                    visible: modelData.oldVersion !== "" && modelData.newVersion !== ""
                                    text: "→"
                                    color: "#cc88ff"
                                    font.pixelSize: updatesTab.fpx(8)
                                }
                                Text {
                                    visible: modelData.newVersion !== ""
                                    text: modelData.newVersion
                                    color: "#cc88ff"
                                    font.pixelSize: updatesTab.fpx(8)
                                    font.bold: true
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                                Text {
                                    visible: modelData.oldVersion === "" && modelData.newVersion !== ""
                                    text: "+ " + modelData.newVersion
                                    color: "#55cc88"
                                    font.pixelSize: updatesTab.fpx(8)
                                    font.bold: true
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: updatesTab.flakeUpdates.length > 0
            text: i18n("Run 'nix flake update' in your config directory to apply.")
            color: updatesTab.textColor
            font.pixelSize: updatesTab.fpx(8)
            opacity: 0.38
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
