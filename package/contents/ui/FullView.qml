import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami as Kirigami
import "components"

Item {
    id: fullView

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }

    // Theme-aware font sizing. Legacy hardcoded sizes were tuned against a 9px base,
    // so divide by 9 to convert legacy values into multipliers of the system small font.
    readonly property int baseFontPx: Kirigami.Theme.smallFont.pixelSize
    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * baseFontPx * fs));
    }

    // ── Required properties ───────────────────────────────────────────────────
    required property color accentColor
    required property color timelineColor
    required property color textColor
    required property real fs
    required property bool showBg
    required property var bgColor
    required property real bgRadius
    required property bool isBusy
    required property bool isLoadingGens
    required property bool isLoadingDetails
    required property bool isCheckingFlake
    required property var generations
    required property var flakeUpdates
    required property var toasts
    required property string lastFlakeCheckTime
    required property int activeGenNum
    required property int bootedGenNum
    required property int selectedGenNum
    required property var detailsCache
    required property string diffFilter
    required property string diffMode
    required property bool showDeleteButton
    required property bool diffFilterEnabled
    required property bool showFlakeSection
    required property bool showCommandButtons
    required property var customCommands
    required property string actionType
    required property int actionGenNum
    required property string activeViewMode   // "timeline" | "updates" | "diff" | "secrets" | "hash"
    required property var sopsStatus         // legacy alias → deployedSecrets
    required property var deployedSecrets  // { path, exists, lastModified, age }
    required property var sourceSecrets    // { path, exists, lastModified, kind }
    required property string hostname
    required property string nixosVersion
    required property string lastActivationTime
    required property string uptime
    required property string iconStyle
    required property real diskStoreBytes
    required property real diskReclaimableBytes
    required property real diskFreeBytes

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0)
            return "";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0, v = bytes;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i >= 3 ? v.toFixed(1) : Math.round(v)) + " " + units[i];
    }

    // Invoked from a timeline card's right-click "Compare with…" menu.
    // Switches to the Diff tab, pre-populates A and B, and triggers the diff fetch.
    function openCompareInDiffTab(genA, genB) {
        diffTab.genA = genA;
        diffTab.genB = genB;
        fullView.viewModeChanged("diff");
        fullView.compareRequested(genA, genB);
    }

    // Pending action for inline confirm bar
    property int pendingGenNum: -1
    property string pendingAction: ""
    property bool usePkexec: false

    // Pairwise diff state for the Diff tab
    property var pairDiffCache: ({})
    property bool isLoadingPairDiff: false
    property string diffViewMode: "compact"   // "compact" | "detailed"
    property var iconCache: ({})
    property var metaCache: ({})
    property bool showPackageIcons: true

    // hash result pushed back from main: { value: string, isError: bool }
    // empty string = no result yet / cleared
    property var hashResult: null

    signal viewModeChanged(string mode)
    signal refreshRequested
    signal checkFlakeRequested
    signal selectGen(int genNum)
    signal collapseGen
    signal requestAction(int genNum, string action)
    signal diffModeToggle(int genNum)
    signal filterChanged(string text)
    signal runCommand(string cmd, string label)
    signal copyToClipboard(string text)
    signal dismissToast(int index)
    signal hashRequested(string mode, string input)
    signal confirmPending
    signal cancelPending
    signal compareRequested(int genA, int genB)
    signal popOutRequested
    signal configureRequested

    property bool isPopOutOpen: false

    // ── Glass background ──────────────────────────────────────────────────────
    // KConfigXT Color drops alpha on save, so opacity is a separate property.
    // We bake it into the color via Qt.rgba so the rect's own `opacity` stays 1.0
    // and can't accidentally affect children or compositing.
    Rectangle {
        anchors.fill: parent
        radius: fullView.bgRadius
        visible: fullView.showBg
        color: fullView.bgColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: fullView.showBg ? 12 : 4
        spacing: 8

        // ── Header ────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Row 1: logo + identity info + icon buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Kirigami.Icon {
                    source: Qt.resolvedUrl("nixos-logo.svg")
                    implicitWidth: 24
                    implicitHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    isMask: fullView.iconStyle !== "colored"
                    color: {
                        if (fullView.iconStyle === "white")
                            return "#ffffff";
                        if (fullView.iconStyle === "black")
                            return "#000000";
                        return fullView.accentColor;
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    // Title: name + gen pill + disk chip
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        Text {
                            text: i18n("Nixdatifier")
                            color: fullView.textColor
                            font.pixelSize: fullView.fpx(13)
                            font.bold: true
                            font.letterSpacing: 0.2
                        }
                        Rectangle {
                            visible: fullView.activeGenNum > 0 && fullView.nixosVersion !== ""
                            radius: 9
                            color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.14)
                            border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.30)
                            border.width: 1
                            implicitWidth: pillText.implicitWidth + 14
                            implicitHeight: 18
                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: "#" + fullView.activeGenNum + "  ·  " + fullView.nixosVersion
                                color: fullView.accentColor
                                font.pixelSize: fullView.fpx(8)
                                font.bold: true
                                font.letterSpacing: 0.3
                            }
                        }
                        Rectangle {
                            readonly property string storeStr: fullView.formatBytes(fullView.diskStoreBytes)
                            readonly property string reclaimStr: fullView.formatBytes(fullView.diskReclaimableBytes)
                            readonly property string freeStr: fullView.formatBytes(fullView.diskFreeBytes)
                            visible: storeStr !== ""
                            implicitWidth: diskChipText.implicitWidth + 14
                            implicitHeight: 18
                            radius: 9
                            color: diskChipMa.containsMouse ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.20) : Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.10)
                            border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.28)
                            border.width: 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 110
                                }
                            }
                            Text {
                                id: diskChipText
                                anchors.centerIn: parent
                                text: parent.storeStr
                                color: fullView.accentColor
                                opacity: 0.92
                                font.pixelSize: fullView.fpx(8)
                                font.bold: true
                                font.letterSpacing: 0.3
                            }
                            MouseArea {
                                id: diskChipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                ToolTip.text: i18n("/nix/store: %1\nReclaimable via GC: %2\n/nix free space: %3").arg(parent.storeStr || i18n("?")).arg(parent.reclaimStr || i18n("?")).arg(parent.freeStr || i18n("?"))
                                ToolTip.visible: containsMouse
                                ToolTip.delay: 400
                            }
                        }
                        // Push remaining space so chips hug the title on the left
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 1
                        }
                    }

                    // Subtitle: hostname · uptime · switched
                    // Each piece independently hides when there's no room — never elide-truncate
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: subtitleRow.implicitHeight

                        RowLayout {
                            id: subtitleRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            readonly property real available: parent.width
                            readonly property bool showSwitched: lastActSized.implicitWidth + uptimeSized.implicitWidth + hostSized.implicitWidth + 24 <= available
                            readonly property bool showUptime: uptimeSized.implicitWidth + hostSized.implicitWidth + 12 <= available

                            Text {
                                id: hostSized
                                visible: fullView.hostname !== ""
                                text: fullView.hostname
                                color: fullView.textColor
                                opacity: 0.50
                                font.pixelSize: fullView.fpx(9)
                                font.weight: Font.Medium
                            }
                            Rectangle {
                                visible: hostSized.visible && uptimeSized.visible
                                width: 2
                                height: 2
                                radius: 1
                                color: fullView.textColor
                                opacity: 0.25
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                id: uptimeSized
                                visible: fullView.uptime !== "" && subtitleRow.showUptime
                                text: i18n("up %1").arg(fullView.uptime)
                                color: fullView.textColor
                                opacity: 0.42
                                font.pixelSize: fullView.fpx(8)
                            }
                            Rectangle {
                                visible: uptimeSized.visible && lastActSized.visible
                                width: 2
                                height: 2
                                radius: 1
                                color: fullView.textColor
                                opacity: 0.25
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                id: lastActSized
                                visible: fullView.lastActivationTime !== "" && subtitleRow.showSwitched
                                text: i18n("switched %1").arg(fullView.lastActivationTime)
                                color: fullView.textColor
                                opacity: 0.42
                                font.pixelSize: fullView.fpx(8)
                            }
                        }
                    }
                }

                // Pin button
                Rectangle {
                    id: pinBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: fullView.isPopOutOpen ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.22) : (pinMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                    border.color: fullView.isPopOutOpen ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.55) : (pinMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 110
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "⬡"
                        color: fullView.isPopOutOpen ? fullView.accentColor : Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.85)
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: pinMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fullView.popOutRequested()
                        ToolTip.text: fullView.isPopOutOpen ? i18n("Unpin (auto-close on focus loss)") : i18n("Pin open (keep visible)")
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                    }
                }

                // Overflow menu (flake-check / configure)
                Rectangle {
                    id: overflowBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: overflowMa.containsMouse || overflowMenu.opened ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                    border.color: overflowMa.containsMouse || overflowMenu.opened ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 110
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -3
                        text: "⋯"
                        color: fullView.textColor
                        opacity: 0.75
                        font.pixelSize: 18
                        font.bold: true
                    }
                    MouseArea {
                        id: overflowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overflowMenu.opened ? overflowMenu.close() : overflowMenu.open()
                        ToolTip.text: i18n("More actions")
                        ToolTip.visible: containsMouse && !overflowMenu.opened
                        ToolTip.delay: 500
                    }
                    Menu {
                        id: overflowMenu
                        y: overflowBtn.height + 4
                        x: overflowBtn.width - implicitWidth
                        MenuItem {
                            text: fullView.isLoadingGens ? i18n("Refreshing generations…") : i18n("Refresh generations list")
                            icon.name: "view-refresh"
                            enabled: !fullView.isLoadingGens
                            onTriggered: fullView.refreshRequested()
                        }
                        MenuItem {
                            text: fullView.isCheckingFlake ? i18n("Checking flake…") : i18n("Check flake for updates")
                            icon.name: "view-refresh"
                            visible: fullView.showFlakeSection
                            height: visible ? implicitHeight : 0
                            enabled: !fullView.isCheckingFlake
                            onTriggered: fullView.checkFlakeRequested()
                        }
                        MenuItem {
                            text: i18n("Configure widget…")
                            icon.name: "configure"
                            onTriggered: fullView.configureRequested()
                        }
                        MenuItem {
                            text: i18n("KDE Store Page")
                            icon.name: "kde"
                            onTriggered: Qt.openUrlExternally("https://store.kde.org/p/2360222/")
                        }
                        MenuItem {
                            text: i18n("GitHub Repository")
                            icon.name: "vcs-code-collaborator"
                            onTriggered: Qt.openUrlExternally("https://github.com/Muddyblack/kde-nixdatifier")
                        }
                    }
                }
            }

            // Row 2: command buttons (left-aligned, only shown when configured)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 34  // align under text column (logo width + gap)
                Layout.topMargin: 2
                spacing: 6
                visible: fullView.showCommandButtons && fullView.customCommands.length > 0

                Repeater {
                    model: fullView.showCommandButtons ? fullView.customCommands.slice(0, 4) : []
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string btnLabel: modelData.label || modelData.cmd || ""
                        readonly property string btnCmd: modelData.cmd || ""
                        readonly property color btnColor: fullView.accentColor

                        visible: btnLabel !== "" && btnCmd !== ""
                        radius: 10
                        implicitWidth: btnLabelText.implicitWidth + 16
                        implicitHeight: 20
                        color: btnMa.containsMouse ? Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.22) : Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.10)
                        border.color: btnMa.containsMouse ? Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.55) : Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.35)
                        border.width: 1
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Text {
                            id: btnLabelText
                            anchors.centerIn: parent
                            text: btnLabel
                            color: btnColor
                            font.pixelSize: fullView.fpx(9)
                            font.bold: true
                            font.letterSpacing: 0.3
                        }
                        MouseArea {
                            id: btnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: fullView.runCommand(btnCmd, btnLabel)
                            ToolTip.text: i18n("Run: %1").arg(btnCmd)
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 600
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        // ── Inline confirm bar ────────────────────────────────────────────────
        Rectangle {
            id: confirmBar
            Layout.fillWidth: true
            visible: fullView.pendingAction !== "" && fullView.pendingGenNum > 0
            implicitHeight: visible ? confirmBarCol.implicitHeight + 14 : 0
            radius: 6
            color: fullView.pendingAction === "delete" ? Qt.rgba(1, 0.25, 0.25, 0.12) : Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.12)
            border.color: fullView.pendingAction === "delete" ? "#ff5555" : fullView.accentColor
            border.width: 1
            clip: true

            ColumnLayout {
                id: confirmBarCol
                anchors.fill: parent
                anchors.margins: 7
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Kirigami.Icon {
                        source: fullView.pendingAction === "delete" ? "edit-delete" : (fullView.pendingAction === "switch" ? "media-playback-start" : "system-reboot")
                        implicitWidth: 18
                        implicitHeight: 18
                        color: fullView.pendingAction === "delete" ? "#ff5555" : fullView.accentColor
                        Layout.alignment: Qt.AlignTop
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: fullView.textColor
                        font.pixelSize: fullView.fpx(10)
                        text: {
                            const pw = fullView.usePkexec ? i18n("  A password prompt will appear.") : "";
                            if (fullView.pendingAction === "delete")
                                return i18n("Permanently delete generation %1? This cannot be undone.").arg(fullView.pendingGenNum) + pw;
                            if (fullView.pendingAction === "switch")
                                return i18n("Activate generation %1 now? Services will restart.").arg(fullView.pendingGenNum) + pw;
                            return i18n("Boot into generation %1 on next reboot?").arg(fullView.pendingGenNum) + pw;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        id: cancelBtn
                        text: i18n("Cancel")
                        implicitHeight: 26
                        font.pixelSize: fullView.fpx(9)
                        onClicked: fullView.cancelPending()
                        background: Rectangle {
                            radius: 4
                            color: cancelBtn.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1
                        }
                        contentItem: Text {
                            text: cancelBtn.text
                            color: fullView.textColor
                            font: cancelBtn.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                            rightPadding: 10
                        }
                    }

                    Button {
                        id: okBtn
                        text: fullView.pendingAction === "delete" ? i18n("Delete") : (fullView.pendingAction === "switch" ? i18n("Activate") : i18n("Set Next Boot"))
                        implicitHeight: 26
                        font.pixelSize: fullView.fpx(9)
                        font.bold: true
                        onClicked: fullView.confirmPending()
                        background: Rectangle {
                            radius: 4
                            color: fullView.pendingAction === "delete" ? (okBtn.hovered ? Qt.rgba(1, 0.25, 0.25, 0.35) : Qt.rgba(1, 0.25, 0.25, 0.20)) : (okBtn.hovered ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.35) : Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.20))
                            border.color: fullView.pendingAction === "delete" ? "#ff5555" : fullView.accentColor
                            border.width: 1
                        }
                        contentItem: Text {
                            text: okBtn.text
                            color: fullView.textColor
                            font: okBtn.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 12
                            rightPadding: 12
                        }
                    }
                }
            }
        }

        // ── Busy bar ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: fullView.isBusy ? 28 : 0
            clip: true
            radius: 5
            color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.12)
            border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.3)
            border.width: 1
            Behavior on height {
                NumberAnimation {
                    duration: 200
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6
                Kirigami.Icon {
                    id: busyBarSpinner
                    source: Qt.resolvedUrl("nixos-logo.svg")
                    isMask: fullView.iconStyle !== "colored"
                    color: {
                        if (fullView.iconStyle === "white")
                            return "#ffffff";
                        if (fullView.iconStyle === "black")
                            return "#000000";
                        return fullView.accentColor;
                    }
                    visible: fullView.isBusy
                    implicitWidth: 18
                    implicitHeight: 18
                    RotationAnimation on rotation {
                        running: busyBarSpinner.visible
                        from: 0
                        to: 360
                        duration: 1400
                        loops: Animation.Infinite
                    }
                }
                Text {
                    text: fullView.actionType === "delete" ? i18n("Deleting generation %1…").arg(fullView.actionGenNum) : (fullView.actionType === "switch" ? i18n("Activating generation %1 (live switch)…").arg(fullView.actionGenNum) : i18n("Setting generation %1 as next boot…").arg(fullView.actionGenNum))
                    color: fullView.textColor
                    font.pixelSize: fullView.fpx(9)
                }
            }
        }

        // ── View mode tab bar (segmented control) ─────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.18)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 0

                Repeater {
                    model: [
                        {
                            id: "timeline",
                            label: i18n("Timeline"),
                            icon: fullView.svg("ic_timeline")
                        },
                        {
                            id: "updates",
                            label: i18n("Updates"),
                            icon: fullView.svg("ic_updates")
                        },
                        {
                            id: "diff",
                            label: i18n("Diff"),
                            icon: fullView.svg("ic_diff")
                        },
                        {
                            id: "secrets",
                            label: i18n("Secrets"),
                            icon: fullView.svg("ic_secrets")
                        },
                        {
                            id: "hash",
                            label: i18n("Hash"),
                            icon: fullView.svg("ic_hash")
                        }
                    ]

                    Rectangle {
                        readonly property bool active: fullView.activeViewMode === modelData.id
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 5
                        color: active ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.20) : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        border.color: active ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.45) : "transparent"
                        border.width: 1
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        // Active accent strip at bottom
                        Rectangle {
                            visible: parent.active
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                leftMargin: 8
                                rightMargin: 8
                                bottomMargin: 2
                            }
                            height: 2
                            radius: 1
                            color: fullView.accentColor
                        }

                        // Update count badge
                        Rectangle {
                            visible: modelData.id === "updates" && fullView.flakeUpdates.length > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 1
                            anchors.rightMargin: 3
                            width: 14
                            height: 14
                            radius: 7
                            color: "#cc88ff"
                            border.color: Kirigami.Theme.backgroundColor
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: fullView.flakeUpdates.length
                                color: "#fff"
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Kirigami.Icon {
                                source: modelData.icon
                                implicitWidth: 13
                                implicitHeight: 13
                                isMask: true
                                color: parent.parent.active ? fullView.accentColor : (tabMouse.containsMouse ? Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.75) : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.45))
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                            }
                            Text {
                                id: tabLabel
                                text: modelData.label
                                color: parent.parent.active ? fullView.accentColor : (tabMouse.containsMouse ? Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.80) : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.50))
                                font.pixelSize: fullView.fpx(9)
                                font.bold: parent.parent.active
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: fullView.viewModeChanged(modelData.id)
                        }
                    }
                }
            }
        }

        // ── Content area ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── TIMELINE view ─────────────────────────────────────────────────
            Item {
                id: timelineTab
                anchors.fill: parent
                visible: fullView.activeViewMode === "timeline"
                focus: visible
                activeFocusOnTab: true

                // Live free-text filter. Matches against gen number, timestamp, the cached
                // nixos version, the kernel string, and any package name in the diff.
                property string searchText: ""

                // Keyboard navigation. Up/Down moves selection through the filtered list,
                // Enter toggles expand, Delete requests removal, `/` focuses search, Esc clears.
                function moveSelection(delta) {
                    const list = timelineTab.filteredGenerations;
                    if (list.length === 0)
                        return;
                    let idx = list.findIndex(g => g.number === fullView.selectedGenNum);
                    if (idx < 0)
                        idx = delta > 0 ? -1 : list.length;
                    const next = Math.max(0, Math.min(list.length - 1, idx + delta));
                    fullView.selectGen(list[next].number);
                    genListView.positionViewAtIndex(next, ListView.Contain);
                }
                Keys.onPressed: event => {
                    if (timelineSearch.activeFocus)
                        return;
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        timelineTab.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        timelineTab.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home) {
                        if (timelineTab.filteredGenerations.length > 0) {
                            fullView.selectGen(timelineTab.filteredGenerations[0].number);
                            genListView.positionViewAtBeginning();
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_End) {
                        const list = timelineTab.filteredGenerations;
                        if (list.length > 0) {
                            fullView.selectGen(list[list.length - 1].number);
                            genListView.positionViewAtEnd();
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (fullView.selectedGenNum > 0) {
                            // Toggle by re-selecting (handler in main collapses if same).
                            fullView.collapseGen();
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Delete && fullView.selectedGenNum > 0 && fullView.showDeleteButton) {
                        fullView.requestAction(fullView.selectedGenNum, "delete");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Slash) {
                        timelineSearch.forceActiveFocus();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        timelineSearch.text = "";
                        event.accepted = true;
                    }
                }

                function genMatches(g) {
                    const q = timelineTab.searchText.trim().toLowerCase();
                    if (!q)
                        return true;
                    if (("#" + g.number).indexOf(q) !== -1)
                        return true;
                    if ((g.timestamp || "").toLowerCase().indexOf(q) !== -1)
                        return true;
                    const d = fullView.detailsCache[g.number];
                    if (d) {
                        if ((d.nixosVer || "").toLowerCase().indexOf(q) !== -1)
                            return true;
                        if ((d.kernelVer || "").toLowerCase().indexOf(q) !== -1)
                            return true;
                        if (d.diff) {
                            for (let i = 0; i < d.diff.length; i++) {
                                if ((d.diff[i].name || "").toLowerCase().indexOf(q) !== -1)
                                    return true;
                            }
                        }
                    }
                    return false;
                }

                readonly property var filteredGenerations: {
                    if (!timelineTab.searchText.trim())
                        return fullView.generations;
                    return fullView.generations.filter(timelineTab.genMatches);
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    // Search bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 5
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: timelineSearch.activeFocus ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 110
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                text: "🔍"
                                color: fullView.textColor
                                opacity: 0.45
                                font.pixelSize: fullView.fpx(9)
                            }
                            TextInput {
                                id: timelineSearch
                                Layout.fillWidth: true
                                font.pixelSize: fullView.fpx(9)
                                color: fullView.textColor
                                clip: true
                                onTextChanged: timelineTab.searchText = text
                                KeyNavigation.priority: KeyNavigation.BeforeItem
                                Keys.onEscapePressed: text = ""

                                Text {
                                    anchors.fill: parent
                                    visible: timelineSearch.text === ""
                                    text: i18n("Search generations, packages, dates…")
                                    color: fullView.textColor
                                    opacity: 0.30
                                    font.pixelSize: fullView.fpx(9)
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            // Result count
                            Text {
                                visible: timelineSearch.text !== ""
                                text: i18n("%1 / %2").arg(timelineTab.filteredGenerations.length).arg(fullView.generations.length)
                                color: fullView.textColor
                                opacity: 0.45
                                font.pixelSize: fullView.fpx(8)
                                font.family: Kirigami.Theme.fixedWidthFont.family
                            }
                            // Clear button
                            Text {
                                visible: timelineSearch.text !== ""
                                text: "×"
                                color: fullView.textColor
                                opacity: clearMa.containsMouse ? 0.85 : 0.55
                                font.pixelSize: fullView.fpx(12)
                                font.bold: true
                                MouseArea {
                                    id: clearMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: timelineSearch.text = ""
                                }
                            }
                        }
                    }

                    ListView {
                        id: genListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: timelineTab.filteredGenerations
                        clip: true
                        spacing: 0
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: GenerationDelegate {
                            width: genListView.width
                            gen: modelData
                            accentColor: fullView.accentColor
                            timelineColor: fullView.timelineColor
                            textColor: fullView.textColor
                            fs: fullView.fs
                            selectedGenNum: fullView.selectedGenNum
                            isLoadingDetails: fullView.isLoadingDetails
                            isBusy: fullView.isBusy
                            detailsCache: fullView.detailsCache
                            diffFilter: fullView.diffFilter
                            diffMode: fullView.diffMode
                            showDeleteButton: fullView.showDeleteButton
                            diffFilterEnabled: fullView.diffFilterEnabled
                            bootedGenNum: fullView.bootedGenNum
                            iconCache: fullView.iconCache
                            metaCache: fullView.metaCache
                            showPackageIcons: fullView.showPackageIcons
                            iconStyle: fullView.iconStyle
                            allGenerations: fullView.generations

                            onSelectGen: n => fullView.selectGen(n)
                            onCollapseGen: () => fullView.collapseGen()
                            onRequestAction: (n, a) => fullView.requestAction(n, a)
                            onDiffModeToggle: n => fullView.diffModeToggle(n)
                            onFilterChanged: t => fullView.filterChanged(t)
                            onCopyToClipboard: t => fullView.copyToClipboard(t)
                            onCompareWithRequested: (a, b) => fullView.openCompareInDiffTab(a, b)
                        }
                    }
                }

                // Loading spinner
                Kirigami.Icon {
                    id: mainSpinner
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("nixos-logo.svg")
                    isMask: fullView.iconStyle !== "colored"
                    color: {
                        if (fullView.iconStyle === "white")
                            return "#ffffff";
                        if (fullView.iconStyle === "black")
                            return "#000000";
                        return fullView.accentColor;
                    }
                    visible: fullView.isLoadingGens && fullView.generations.length === 0
                    width: 64
                    height: 64
                    RotationAnimation on rotation {
                        running: mainSpinner.visible
                        from: 0
                        to: 360
                        duration: 1400
                        loops: Animation.Infinite
                    }
                }

                // Empty state — three flavors:
                //   1. No flake configured yet (first run)
                //   2. Generations probe failed (perm error, profiles dir missing)
                //   3. Search returned no matches
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    width: Math.min(parent.width - 40, 320)

                    readonly property bool noGenerations: fullView.generations.length === 0 && !fullView.isLoadingGens
                    readonly property bool noMatches: fullView.generations.length > 0 && timelineTab.filteredGenerations.length === 0 && timelineTab.searchText.trim() !== ""

                    visible: noGenerations || noMatches

                    Kirigami.Icon {
                        source: parent.noMatches ? "edit-find" : "dialog-warning"
                        implicitWidth: 44
                        implicitHeight: 44
                        opacity: 0.40
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: fullView.accentColor
                        isMask: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.noMatches ? i18n("No matches") : i18n("No generations found")
                        color: fullView.textColor
                        opacity: 0.85
                        font.pixelSize: fullView.fpx(12)
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        Layout.fillWidth: true
                        width: parent.width
                        text: parent.noMatches ? i18n("Nothing matches \"%1\". Try a partial package name, a generation number, or a date.").arg(timelineTab.searchText) : i18n("Check that /nix/var/nix/profiles/ exists and is readable. If you just installed NixOS you should have at least one generation — try refreshing.")
                        color: fullView.textColor
                        opacity: 0.55
                        font.pixelSize: fullView.fpx(9)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        Button {
                            visible: parent.parent.noMatches
                            text: i18n("Clear search")
                            font.pixelSize: fullView.fpx(9)
                            onClicked: timelineSearch.text = ""
                        }
                        Button {
                            visible: !parent.parent.noMatches
                            text: i18n("Refresh")
                            font.pixelSize: fullView.fpx(9)
                            onClicked: fullView.refreshRequested()
                        }
                        Button {
                            visible: !parent.parent.noMatches
                            text: i18n("Configure…")
                            font.pixelSize: fullView.fpx(9)
                            onClicked: fullView.configureRequested()
                        }
                    }
                }
            }

            // ── UPDATES view ──────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: fullView.activeViewMode === "updates"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Kirigami.Icon {
                            source: fullView.svg("ic_updates")
                            isMask: true
                            implicitWidth: 18
                            implicitHeight: 18
                            color: "#cc88ff"
                        }
                        Text {
                            text: fullView.isCheckingFlake ? i18n("Checking flake updates…") : (fullView.flakeUpdates.length > 0 ? (fullView.flakeUpdates.length === 1 ? i18n("1 flake update available") : i18n("%1 flake updates available").arg(fullView.flakeUpdates.length)) : (fullView.lastFlakeCheckTime !== "" ? i18n("All inputs up-to-date · %1").arg(fullView.lastFlakeCheckTime) : i18n("Flake up-to-date")))
                            color: fullView.flakeUpdates.length > 0 ? "#cc88ff" : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.5)
                            font.pixelSize: fullView.fpx(11)
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
                            isMask: fullView.iconStyle !== "colored"
                            color: {
                                if (fullView.iconStyle === "white")
                                    return "#ffffff";
                                if (fullView.iconStyle === "black")
                                    return "#000000";
                                return fullView.accentColor;
                            }
                            visible: fullView.isCheckingFlake
                            implicitWidth: 18
                            implicitHeight: 18
                            RotationAnimation on rotation {
                                running: updateSpinner.visible
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
                        model: fullView.flakeUpdates
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: fullView.flakeUpdates.length === 0 && !fullView.isCheckingFlake
                            text: i18n("No pending flake updates")
                            color: fullView.textColor
                            font.pixelSize: fullView.fpx(10)
                            opacity: 0.35
                        }

                        delegate: Rectangle {
                            width: parent ? parent.width : 0
                            height: 44
                            radius: 6
                            color: updateRowMa.containsMouse ? Qt.rgba(0.7, 0.4, 1, 0.10) : Qt.rgba(0.7, 0.4, 1, 0.05)
                            border.color: Qt.rgba(0.7, 0.4, 1, 0.22)
                            border.width: 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            MouseArea {
                                id: updateRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                // URLs are derived from flake.lock entries, which the user controls
                                // — a malicious flake input could in principle store a file:// or
                                // javascript: URL. Gate xdg-open to http(s).
                                readonly property bool isSafeUrl: !!modelData.url && /^https?:\/\//i.test(modelData.url)
                                cursorShape: isSafeUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (isSafeUrl)
                                    Qt.openUrlExternally(modelData.url)
                                ToolTip.text: modelData.url || ""
                                ToolTip.visible: containsMouse && isSafeUrl
                                ToolTip.delay: 500
                            }

                            // Accent stripe on the left
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
                                    source: fullView.svg("ic_package_added")
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
                                        color: fullView.textColor
                                        font.pixelSize: fullView.fpx(11)
                                        font.bold: true
                                    }
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: modelData.oldRev
                                            color: fullView.textColor
                                            font.pixelSize: fullView.fpx(8)
                                            opacity: 0.5
                                            font.family: Kirigami.Theme.fixedWidthFont.family
                                        }
                                        Text {
                                            text: "→"
                                            color: "#cc88ff"
                                            font.pixelSize: fullView.fpx(8)
                                        }
                                        Text {
                                            text: modelData.newRev
                                            color: "#cc88ff"
                                            font.pixelSize: fullView.fpx(8)
                                            font.bold: true
                                            font.family: Kirigami.Theme.fixedWidthFont.family
                                        }
                                        Text {
                                            visible: modelData.oldDate !== ""
                                            text: "·  " + modelData.oldDate
                                            color: fullView.textColor
                                            font.pixelSize: fullView.fpx(8)
                                            opacity: 0.4
                                        }
                                    }
                                }

                                Text {
                                    visible: !!(modelData.url && modelData.url !== "")
                                    text: "↗"
                                    color: "#cc88ff"
                                    opacity: updateRowMa.containsMouse ? 0.95 : 0.55
                                    font.pixelSize: fullView.fpx(13)
                                    font.bold: true
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 120
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: fullView.flakeUpdates.length > 0
                        text: i18n("Run 'nix flake update' in your config directory to apply.")
                        color: fullView.textColor
                        font.pixelSize: fullView.fpx(8)
                        opacity: 0.38
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── DIFF view ─────────────────────────────────────────────────────
            Item {
                id: diffTab
                anchors.fill: parent
                visible: fullView.activeViewMode === "diff"

                property int genA: fullView.generations.length > 0 ? fullView.generations[0].number : -1
                property int genB: fullView.generations.length > 1 ? fullView.generations[1].number : -1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Picker row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: i18n("Compare:")
                            color: fullView.textColor
                            opacity: 0.6
                            font.pixelSize: fullView.fpx(10)
                        }

                        // ── Custom picker A ───────────────────────────────────
                        Item {
                            id: pickerA
                            implicitWidth: 86
                            implicitHeight: 26
                            property int selectedIndex: 0
                            property bool open: false

                            onSelectedIndexChanged: {
                                if (fullView.generations.length > selectedIndex)
                                    diffTab.genA = fullView.generations[selectedIndex].number;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: pickerA.open ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.14) : (pickerAMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
                                border.color: pickerA.open ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                            }
                            Text {
                                anchors {
                                    left: parent.left
                                    right: chevA.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 8
                                    rightMargin: 2
                                }
                                text: fullView.generations.length > pickerA.selectedIndex ? "#" + fullView.generations[pickerA.selectedIndex].number : "—"
                                color: fullView.textColor
                                font.pixelSize: fullView.fpx(9)
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                id: chevA
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    rightMargin: 6
                                }
                                text: pickerA.open ? "▲" : "▼"
                                color: fullView.textColor
                                opacity: 0.45
                                font.pixelSize: fullView.fpx(7)
                            }
                            MouseArea {
                                id: pickerAMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pickerA.open = !pickerA.open;
                                    pickerB.open = false;
                                }
                            }

                            Popup {
                                id: popupA
                                visible: pickerA.open
                                y: pickerA.height + 3
                                x: 0
                                width: Math.max(pickerA.width, 92)
                                padding: 4
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                                onClosed: pickerA.open = false
                                background: Rectangle {
                                    radius: 6
                                    color: Qt.rgba(0.08, 0.06, 0.14, 0.98)
                                    border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.35)
                                    border.width: 1
                                }
                                contentItem: ListView {
                                    implicitHeight: Math.min(contentHeight, 200)
                                    clip: true
                                    model: fullView.generations
                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                    }
                                    delegate: Rectangle {
                                        width: popupA.width - 8
                                        height: 26
                                        radius: 4
                                        color: pickerA.selectedIndex === index ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.25) : (rowMaA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 80
                                            }
                                        }
                                        Text {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                verticalCenter: parent.verticalCenter
                                                leftMargin: 10
                                                rightMargin: 6
                                            }
                                            text: "#" + modelData.number
                                            color: fullView.textColor
                                            font.pixelSize: fullView.fpx(9)
                                            font.bold: pickerA.selectedIndex === index
                                        }
                                        MouseArea {
                                            id: rowMaA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                pickerA.selectedIndex = index;
                                                pickerA.open = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: i18n("vs")
                            color: fullView.textColor
                            opacity: 0.45
                            font.pixelSize: fullView.fpx(10)
                        }

                        // ── Custom picker B ───────────────────────────────────
                        Item {
                            id: pickerB
                            implicitWidth: 86
                            implicitHeight: 26
                            property int selectedIndex: Math.min(1, fullView.generations.length - 1)
                            property bool open: false

                            onSelectedIndexChanged: {
                                if (fullView.generations.length > selectedIndex)
                                    diffTab.genB = fullView.generations[selectedIndex].number;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: pickerB.open ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.14) : (pickerBMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
                                border.color: pickerB.open ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                            }
                            Text {
                                anchors {
                                    left: parent.left
                                    right: chevB.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 8
                                    rightMargin: 2
                                }
                                text: fullView.generations.length > pickerB.selectedIndex ? "#" + fullView.generations[pickerB.selectedIndex].number : "—"
                                color: fullView.textColor
                                font.pixelSize: fullView.fpx(9)
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                id: chevB
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    rightMargin: 6
                                }
                                text: pickerB.open ? "▲" : "▼"
                                color: fullView.textColor
                                opacity: 0.45
                                font.pixelSize: fullView.fpx(7)
                            }
                            MouseArea {
                                id: pickerBMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pickerB.open = !pickerB.open;
                                    pickerA.open = false;
                                }
                            }

                            Popup {
                                id: popupB
                                visible: pickerB.open
                                y: pickerB.height + 3
                                x: 0
                                width: Math.max(pickerB.width, 92)
                                padding: 4
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                                onClosed: pickerB.open = false
                                background: Rectangle {
                                    radius: 6
                                    color: Qt.rgba(0.08, 0.06, 0.14, 0.98)
                                    border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.35)
                                    border.width: 1
                                }
                                contentItem: ListView {
                                    implicitHeight: Math.min(contentHeight, 200)
                                    clip: true
                                    model: fullView.generations
                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                    }
                                    delegate: Rectangle {
                                        width: popupB.width - 8
                                        height: 26
                                        radius: 4
                                        color: pickerB.selectedIndex === index ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.25) : (rowMaB.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 80
                                            }
                                        }
                                        Text {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                verticalCenter: parent.verticalCenter
                                                leftMargin: 10
                                                rightMargin: 6
                                            }
                                            text: "#" + modelData.number
                                            color: fullView.textColor
                                            font.pixelSize: fullView.fpx(9)
                                            font.bold: pickerB.selectedIndex === index
                                        }
                                        MouseArea {
                                            id: rowMaB
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                pickerB.selectedIndex = index;
                                                pickerB.open = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Compare button
                        Rectangle {
                            id: compareBtn
                            readonly property bool active: diffTab.genA !== diffTab.genB && diffTab.genA > 0 && diffTab.genB > 0 && !fullView.isLoadingPairDiff
                            implicitHeight: 26
                            implicitWidth: compareRow.implicitWidth + 20
                            radius: 6

                            color: active ? (compareMa.containsMouse ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.25) : Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.12)) : Qt.rgba(1, 1, 1, 0.04)

                            border.color: active ? (compareMa.containsMouse ? fullView.accentColor : Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.5)) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            RowLayout {
                                id: compareRow
                                anchors.centerIn: parent
                                spacing: 6

                                Kirigami.Icon {
                                    source: fullView.svg("ic_diff")
                                    isMask: true
                                    implicitWidth: 12
                                    implicitHeight: 12
                                    color: compareBtn.active ? fullView.accentColor : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.3)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }

                                Text {
                                    text: fullView.isLoadingPairDiff ? i18n("Loading…") : i18n("Compare")
                                    color: compareBtn.active ? fullView.accentColor : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.3)
                                    font.pixelSize: fullView.fpx(9)
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: compareMa
                                anchors.fill: parent
                                hoverEnabled: compareBtn.active
                                cursorShape: compareBtn.active ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (compareBtn.active) {
                                        fullView.compareRequested(diffTab.genA, diffTab.genB);
                                    }
                                }
                            }
                        }
                    }

                    // ── Meta strip (shown once results are loaded) ────────────
                    Rectangle {
                        Layout.fillWidth: true
                        visible: {
                            const k = diffTab.genA + "_" + diffTab.genB;
                            return !!(fullView.pairDiffCache[k]);
                        }
                        height: metaRow.implicitHeight + 14
                        radius: 6
                        color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.07)
                        border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.20)
                        border.width: 1

                        RowLayout {
                            id: metaRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 8
                            }
                            spacing: 16

                            // A gen info (FROM = genB)
                            Column {
                                spacing: 1
                                Text {
                                    text: i18n("FROM")
                                    color: fullView.textColor
                                    opacity: 0.35
                                    font.pixelSize: fullView.fpx(6.5)
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                }
                                Text {
                                    text: "#" + diffTab.genB + (fullView.detailsCache[diffTab.genB] ? "  ·  " + fullView.detailsCache[diffTab.genB].nixosVer : "")
                                    color: fullView.textColor
                                    font.pixelSize: fullView.fpx(9)
                                    font.bold: true
                                }
                                Text {
                                    visible: !!(fullView.detailsCache[diffTab.genB] && fullView.detailsCache[diffTab.genB].commitDate)
                                    text: fullView.detailsCache[diffTab.genB] ? fullView.detailsCache[diffTab.genB].commitDate : ""
                                    color: fullView.textColor
                                    opacity: 0.38
                                    font.pixelSize: fullView.fpx(7.5)
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                            }

                            Text {
                                text: "→"
                                color: fullView.accentColor
                                font.pixelSize: fullView.fpx(13)
                                font.bold: true
                                opacity: 0.8
                            }

                            // B gen info (TO = genA)
                            Column {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: i18n("TO")
                                    color: fullView.textColor
                                    opacity: 0.35
                                    font.pixelSize: fullView.fpx(6.5)
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                }
                                Text {
                                    text: "#" + diffTab.genA + (fullView.detailsCache[diffTab.genA] ? "  ·  " + fullView.detailsCache[diffTab.genA].nixosVer : "")
                                    color: fullView.textColor
                                    font.pixelSize: fullView.fpx(9)
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    visible: !!(fullView.detailsCache[diffTab.genA] && fullView.detailsCache[diffTab.genA].commitDate)
                                    text: fullView.detailsCache[diffTab.genA] ? fullView.detailsCache[diffTab.genA].commitDate : ""
                                    color: fullView.textColor
                                    opacity: 0.38
                                    font.pixelSize: fullView.fpx(7.5)
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            // Change counts
                            RowLayout {
                                spacing: 6
                                Repeater {
                                    model: [
                                        {
                                            type: "added",
                                            label: i18n("added"),
                                            color: "#3ddc84"
                                        },
                                        {
                                            type: "removed",
                                            label: i18n("removed"),
                                            color: "#ff6b6b"
                                        },
                                        {
                                            type: "upgrade",
                                            label: i18n("changed"),
                                            color: "#ffb74d"
                                        }
                                    ]
                                    Rectangle {
                                        readonly property int typeCount: {
                                            const k = diffTab.genA + "_" + diffTab.genB;
                                            const e = fullView.pairDiffCache[k];
                                            return e ? e.diff.filter(d => d.type === modelData.type).length : 0;
                                        }
                                        visible: typeCount > 0
                                        height: 18
                                        radius: 4
                                        width: pillLabel.implicitWidth + 10
                                        color: Qt.rgba(0, 0, 0, 0.0)
                                        border.color: modelData.color
                                        border.width: 1
                                        Text {
                                            id: pillLabel
                                            anchors.centerIn: parent
                                            text: parent.typeCount + " " + modelData.label
                                            color: modelData.color
                                            font.pixelSize: fullView.fpx(7.5)
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Sub-toolbar: count + mode toggle ─────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Total count badge
                        Rectangle {
                            visible: {
                                const k = diffTab.genA + "_" + diffTab.genB;
                                const e = fullView.pairDiffCache[k];
                                return !!(e && e.diff.length > 0);
                            }
                            height: 16
                            radius: 8
                            width: totalLbl.implicitWidth + 12
                            color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.18)
                            border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.50)
                            border.width: 1
                            Text {
                                id: totalLbl
                                anchors.centerIn: parent
                                text: {
                                    const k = diffTab.genA + "_" + diffTab.genB;
                                    const e = fullView.pairDiffCache[k];
                                    return e ? e.diff.length + " " + i18n("packages") : "";
                                }
                                color: fullView.accentColor
                                font.pixelSize: fullView.fpx(7.5)
                                font.bold: true
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Compact / Detailed mode toggle (apdatifier-style segmented pill)
                        Rectangle {
                            height: 24
                            radius: 6
                            width: modeToggleRow.implicitWidth + 4
                            color: Qt.rgba(0, 0, 0, 0.20)
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            RowLayout {
                                id: modeToggleRow
                                anchors.centerIn: parent
                                spacing: 2
                                anchors.margins: 2

                                Repeater {
                                    model: [
                                        {
                                            id: "compact",
                                            icon: fullView.svg("ic_timeline"),
                                            tip: i18n("Compact view")
                                        },
                                        {
                                            id: "detailed",
                                            icon: fullView.svg("ic_diff"),
                                            tip: i18n("Detailed view")
                                        }
                                    ]
                                    Rectangle {
                                        readonly property bool active: fullView.diffViewMode === modelData.id
                                        width: 28
                                        height: 20
                                        radius: 4
                                        color: active ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.28) : (modePillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                        border.color: active ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.55) : "transparent"
                                        border.width: 1
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 100
                                            }
                                        }

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            source: modelData.icon
                                            implicitWidth: 13
                                            implicitHeight: 13
                                            isMask: true
                                            color: parent.active ? fullView.accentColor : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.50)
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 100
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: modePillMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: fullView.diffViewMode = modelData.id
                                            ToolTip.text: modelData.tip
                                            ToolTip.visible: containsMouse
                                            ToolTip.delay: 400
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Package list ──────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.18)
                        border.color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        clip: true

                        ListView {
                            id: diffTabView
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            spacing: 1
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            readonly property string pairKey: diffTab.genA + "_" + diffTab.genB
                            model: {
                                const entry = fullView.pairDiffCache[diffTabView.pairKey];
                                return entry ? entry.diff : [];
                            }

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 32
                                visible: diffTabView.count === 0
                                text: fullView.isLoadingPairDiff ? i18n("Computing diff…") : (diffTab.genA > 0 && diffTab.genA === diffTab.genB ? i18n("Select two different generations") : (fullView.pairDiffCache[diffTabView.pairKey] ? i18n("No package differences") : i18n("Pick two generations and click Compare")))
                                color: fullView.textColor
                                opacity: 0.40
                                font.pixelSize: fullView.fpx(10)
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            delegate: PackageRow {
                                width: diffTabView.width
                                pkg: modelData
                                accentColor: fullView.accentColor
                                textColor: fullView.textColor
                                fs: fullView.fs
                                forceExpanded: fullView.diffViewMode === "detailed"
                                iconCache: fullView.iconCache
                                metaCache: fullView.metaCache
                                showPackageIcons: fullView.showPackageIcons
                                onCopyRequested: text => fullView.copyToClipboard(text)
                            }
                        }
                    }
                }
            }

            // ── SECRETS view ──────────────────────────────────────────────────
            Item {
                id: secretsView
                anchors.fill: parent
                visible: fullView.activeViewMode === "secrets"

                readonly property bool nothingConfigured: fullView.deployedSecrets.path === "" && fullView.sourceSecrets.path === ""

                // helper: human-readable encryption label
                function encLabel(s) {
                    if (!s.exists)
                        return "";
                    const k = s.encKind || "";
                    const t = s.encType || "";
                    if (k === "encrypted") {
                        const tLabel = t === "age" ? "age" : t === "pgp" ? "PGP" : t === "mixed" ? "age+PGP" : t;
                        return "SOPS" + (tLabel ? " / " + tLabel : "");
                    }
                    if (k === "plain")
                        return i18n("Plaintext — not encrypted!");
                    if (k === "directory")
                        return i18n("Directory");
                    return k;
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ── Section header ────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Layout.bottomMargin: 8

                        Kirigami.Icon {
                            source: fullView.svg("ic_secrets")
                            isMask: true
                            implicitWidth: 20
                            implicitHeight: 20
                            color: fullView.deployedSecrets.exists || fullView.sourceSecrets.exists ? "#55cc55" : "#ff5555"
                        }

                        Text {
                            text: i18n("SOPS / Agenix Secrets")
                            color: fullView.textColor
                            font.pixelSize: fullView.fpx(12)
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Layout.bottomMargin: 8
                    }

                    // scrollable body
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: secretsBody.implicitHeight
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        ColumnLayout {
                            id: secretsBody
                            width: parent.width
                            spacing: 0

                            // ── DEPLOYED block ────────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Layout.bottomMargin: 10

                                // Sub-header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Layout.bottomMargin: 2

                                    Text {
                                        text: i18n("Deployed")
                                        color: fullView.textColor
                                        font.pixelSize: fullView.fpx(10)
                                        font.bold: true
                                        opacity: 0.7
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        radius: 3
                                        color: fullView.deployedSecrets.exists ? Qt.rgba(0.2, 0.8, 0.3, 0.15) : Qt.rgba(1, 0.2, 0.2, 0.15)
                                        border.color: fullView.deployedSecrets.exists ? "#55cc55" : "#ff5555"
                                        border.width: 1
                                        width: deployedPill.implicitWidth + 12
                                        height: 17
                                        Text {
                                            id: deployedPill
                                            anchors.centerIn: parent
                                            text: fullView.deployedSecrets.exists ? i18n("OK") : i18n("Missing")
                                            color: fullView.deployedSecrets.exists ? "#55cc55" : "#ff5555"
                                            font.pixelSize: fullView.fpx(8)
                                            font.bold: true
                                        }
                                    }
                                }

                                // rows
                                Repeater {
                                    model: {
                                        const d = fullView.deployedSecrets;
                                        const rows = [];
                                        rows.push({
                                            label: i18n("Path:"),
                                            value: d.path || i18n("Auto-detecting…"),
                                            dim: !d.path
                                        });
                                        if (d.exists) {
                                            rows.push({
                                                label: i18n("Last modified:"),
                                                value: d.lastModified || "—",
                                                dim: false
                                            });
                                            rows.push({
                                                label: i18n("Freshness:"),
                                                value: d.freshness || "—",
                                                dim: false,
                                                fresh: d.freshness
                                            });
                                            rows.push({
                                                label: i18n("Secrets:"),
                                                value: d.fileCount + (d.fileCount === 1 ? " " + i18n("file") : " " + i18n("files")),
                                                dim: false
                                            });
                                        }
                                        return rows;
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text {
                                            text: modelData.label
                                            color: fullView.textColor
                                            opacity: 0.42
                                            font.pixelSize: fullView.fpx(9)
                                            Layout.minimumWidth: 100
                                        }
                                        Text {
                                            text: modelData.value
                                            color: modelData.fresh === "fresh" ? "#55cc55" : modelData.fresh === "stale" ? "#ffaa44" : fullView.textColor
                                            font.pixelSize: fullView.fpx(9)
                                            opacity: modelData.dim ? 0.38 : 0.85
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Secret name chips (if any are listed)
                                Flow {
                                    visible: fullView.deployedSecrets.exists && fullView.deployedSecrets.names.length > 0
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Layout.topMargin: 2

                                    Repeater {
                                        model: fullView.deployedSecrets.names
                                        Rectangle {
                                            radius: 3
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1
                                            width: chipTxt.implicitWidth + 10
                                            height: chipTxt.implicitHeight + 5
                                            Text {
                                                id: chipTxt
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: fullView.textColor
                                                opacity: 0.7
                                                font.pixelSize: fullView.fpx(8)
                                                font.family: Kirigami.Theme.fixedWidthFont.family
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Divider ───────────────────────────────────────
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.06)
                                Layout.bottomMargin: 10
                                visible: fullView.sourceSecrets.path !== ""
                            }

                            // ── SOURCE block ──────────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: fullView.sourceSecrets.path !== ""

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Layout.bottomMargin: 2

                                    Text {
                                        text: i18n("Source (encrypted)")
                                        color: fullView.textColor
                                        font.pixelSize: fullView.fpx(10)
                                        font.bold: true
                                        opacity: 0.7
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        radius: 3
                                        color: fullView.sourceSecrets.exists ? Qt.rgba(0.2, 0.8, 0.3, 0.15) : Qt.rgba(1, 0.2, 0.2, 0.15)
                                        border.color: fullView.sourceSecrets.exists ? "#55cc55" : "#ff5555"
                                        border.width: 1
                                        width: sourcePill.implicitWidth + 12
                                        height: 17
                                        Text {
                                            id: sourcePill
                                            anchors.centerIn: parent
                                            text: fullView.sourceSecrets.exists ? i18n("OK") : i18n("Missing")
                                            color: fullView.sourceSecrets.exists ? "#55cc55" : "#ff5555"
                                            font.pixelSize: fullView.fpx(8)
                                            font.bold: true
                                        }
                                    }
                                }

                                Repeater {
                                    model: {
                                        const s = fullView.sourceSecrets;
                                        const rows = [];
                                        rows.push({
                                            label: i18n("Path:"),
                                            value: s.path || i18n("Not configured"),
                                            dim: !s.path,
                                            warn: false
                                        });
                                        if (s.exists) {
                                            rows.push({
                                                label: i18n("Last modified:"),
                                                value: s.lastModified || "—",
                                                dim: false,
                                                warn: false
                                            });
                                            const enc = secretsView.encLabel(s);
                                            rows.push({
                                                label: i18n("Format:"),
                                                value: enc || "—",
                                                dim: false,
                                                warn: s.encKind === "plain"
                                            });
                                            if (s.sopsVersion)
                                                rows.push({
                                                    label: i18n("SOPS:"),
                                                    value: "v" + s.sopsVersion,
                                                    dim: false,
                                                    warn: false
                                                });
                                            if (s.recipientCount > 0)
                                                rows.push({
                                                    label: i18n("Recipients:"),
                                                    value: s.recipientCount + (s.encType ? " (" + s.encType + ")" : ""),
                                                    dim: false,
                                                    warn: false
                                                });
                                        }
                                        return rows;
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text {
                                            text: modelData.label
                                            color: fullView.textColor
                                            opacity: 0.42
                                            font.pixelSize: fullView.fpx(9)
                                            Layout.minimumWidth: 100
                                        }
                                        Text {
                                            text: modelData.value
                                            color: modelData.warn ? "#ffaa44" : fullView.textColor
                                            font.pixelSize: fullView.fpx(9)
                                            opacity: modelData.dim ? 0.38 : 0.85
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Secret name chips
                                Flow {
                                    visible: fullView.sourceSecrets.exists && fullView.sourceSecrets.names.length > 0
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Layout.topMargin: 2

                                    Repeater {
                                        model: fullView.sourceSecrets.names
                                        Rectangle {
                                            radius: 3
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1
                                            width: srcChip.implicitWidth + 10
                                            height: srcChip.implicitHeight + 5
                                            Text {
                                                id: srcChip
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: fullView.textColor
                                                opacity: 0.7
                                                font.pixelSize: fullView.fpx(8)
                                                font.family: Kirigami.Theme.fixedWidthFont.family
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Nothing configured ────────────────────────────
                            Text {
                                visible: secretsView.nothingConfigured
                                text: i18n("No secrets found.\nDeployed secrets are auto-detected at /run/secrets or /run/agenix.d.\nSet a source file path in Settings → Behavior.")
                                color: fullView.textColor
                                opacity: 0.38
                                font.pixelSize: fullView.fpx(9)
                                wrapMode: Text.WordWrap
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ── HASH view ─────────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: fullView.activeViewMode === "hash"

                signal hashRequested(string mode, string input)

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    // ── Mode selector ─────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                {
                                    id: "url",
                                    label: i18n("URL"),
                                    tip: i18n("sha256 of a remote file (fetchurl)")
                                },
                                {
                                    id: "zip",
                                    label: i18n("Zip/Tar"),
                                    tip: i18n("sha256 of an unpacked archive (fetchzip)")
                                },
                                {
                                    id: "github",
                                    label: i18n("GitHub"),
                                    tip: i18n("owner/repo/rev → sha256 (fetchFromGitHub)")
                                },
                                {
                                    id: "file",
                                    label: i18n("File"),
                                    tip: i18n("sha256sum of a local file")
                                },
                                {
                                    id: "store",
                                    label: i18n("Store"),
                                    tip: i18n("NAR hash of a /nix/store/... path")
                                }
                            ]

                            Rectangle {
                                readonly property bool active: hashModeHolder.value === modelData.id
                                radius: 4
                                height: 24
                                width: modeLbl.implicitWidth + 14
                                color: active ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.22) : (modeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03))
                                border.color: active ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.5) : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 110
                                    }
                                }

                                Text {
                                    id: modeLbl
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: active ? fullView.accentColor : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.65)
                                    font.pixelSize: fullView.fpx(9)
                                    font.bold: active
                                }

                                ToolTip.text: modelData.tip
                                ToolTip.visible: modeMa.containsMouse
                                ToolTip.delay: 500

                                MouseArea {
                                    id: modeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        hashModeHolder.value = modelData.id;
                                        hashInputField.text = "";
                                        hashResultField.text = "";
                                        hashResultField.isError = false;
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    // Hidden mode holder (no visual, just state)
                    Item {
                        id: hashModeHolder
                        visible: false
                        property string value: "url"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // ── Placeholder hint ──────────────────────────────────────
                    Text {
                        Layout.fillWidth: true
                        text: {
                            switch (hashModeHolder.value) {
                            case "url":
                                return i18n("https://example.com/file.tar.gz");
                            case "zip":
                                return i18n("https://example.com/archive.zip");
                            case "github":
                                return i18n("owner/repo/v1.2.3   or   owner/repo/abc1234");
                            case "file":
                                return i18n("/path/to/local/file");
                            case "store":
                                return i18n("/nix/store/abc123...-some-package");
                            default:
                                return "";
                            }
                        }
                        color: fullView.textColor
                        opacity: 0.35
                        font.pixelSize: fullView.fpx(8)
                        font.italic: true
                        wrapMode: Text.Wrap
                    }

                    // ── Input field ───────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        TextField {
                            id: hashInputField
                            Layout.fillWidth: true
                            implicitHeight: 28
                            font.pixelSize: fullView.fpx(9)
                            font.family: Kirigami.Theme.fixedWidthFont.family
                            placeholderText: i18n("Enter input…")
                            leftPadding: 8
                            rightPadding: 8
                            color: fullView.textColor
                            onAccepted: hashRunButton.clicked()
                            background: Rectangle {
                                radius: 4
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.color: hashInputField.activeFocus ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.6) : Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }
                        }

                        Button {
                            id: hashRunButton
                            text: hashSpinner.visible ? "" : i18n("Get Hash")
                            implicitHeight: 28
                            enabled: hashInputField.text.trim() !== "" && !hashSpinner.visible
                            font.pixelSize: fullView.fpx(9)
                            font.bold: true

                            onClicked: {
                                hashResultField.text = "";
                                hashResultField.isError = false;
                                fullView.hashRequested(hashModeHolder.value, hashInputField.text.trim());
                            }

                            background: Rectangle {
                                radius: 4
                                color: parent.enabled ? (parent.hovered ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.30) : Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.16)) : Qt.rgba(1, 1, 1, 0.04)
                                border.color: parent.enabled ? fullView.accentColor : Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1
                            }
                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Kirigami.Icon {
                                    id: hashSpinner
                                    source: Qt.resolvedUrl("nixos-logo.svg")
                                    isMask: fullView.iconStyle !== "colored"
                                    color: {
                                        if (fullView.iconStyle === "white")
                                            return "#ffffff";
                                        if (fullView.iconStyle === "black")
                                            return "#000000";
                                        return fullView.accentColor;
                                    }
                                    visible: false
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    RotationAnimation on rotation {
                                        running: hashSpinner.visible
                                        from: 0
                                        to: 360
                                        duration: 1200
                                        loops: Animation.Infinite
                                    }
                                }
                                Text {
                                    visible: !hashSpinner.visible
                                    text: hashRunButton.text
                                    color: hashRunButton.enabled ? fullView.textColor : Qt.rgba(fullView.textColor.r, fullView.textColor.g, fullView.textColor.b, 0.4)
                                    font: hashRunButton.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    // ── Result field ──────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: hashResultField.text !== "" ? hashResultRow.implicitHeight + 16 : 0
                        clip: true
                        radius: 5
                        color: hashResultField.isError ? Qt.rgba(1, 0.2, 0.2, 0.12) : Qt.rgba(0.2, 0.85, 0.2, 0.09)
                        border.color: hashResultField.isError ? "#ff5555" : "#55cc55"
                        border.width: 1
                        Behavior on height {
                            NumberAnimation {
                                duration: 180
                            }
                        }
                        visible: height > 0

                        RowLayout {
                            id: hashResultRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 6

                            TextEdit {
                                id: hashResultField
                                property bool isError: false
                                Layout.fillWidth: true
                                readOnly: true
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: fullView.fpx(9)
                                font.family: Kirigami.Theme.fixedWidthFont.family
                                color: isError ? "#ff7777" : "#88ff88"
                                selectByMouse: true
                                // Make selection visible
                                selectionColor: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.35)
                            }

                            ToolButton {
                                visible: !hashResultField.isError && hashResultField.text !== ""
                                icon.name: "edit-copy"
                                implicitWidth: 22
                                implicitHeight: 22
                                ToolTip.text: i18n("Copy hash")
                                ToolTip.visible: hovered
                                ToolTip.delay: 400
                                onClicked: fullView.copyToClipboard(hashResultField.text)
                            }
                        }
                    }

                    // ── SRI format toggle + formatted output ──────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        visible: hashResultField.text !== "" && !hashResultField.isError && !hashResultField.text.startsWith("sha256:") && !hashResultField.text.startsWith("sha256-")
                        spacing: 8

                        Text {
                            text: i18n("As SRI:")
                            color: fullView.textColor
                            opacity: 0.5
                            font.pixelSize: fullView.fpx(8)
                        }

                        TextEdit {
                            id: sriField
                            readOnly: true
                            selectByMouse: true
                            text: hashResultField.text !== "" && !hashResultField.isError ? "sha256-" + Qt.btoa(hashResultField.text.replace(/([0-9a-f]{2})/gi, (m, h) => String.fromCharCode(parseInt(h, 16)))) : ""
                            font.pixelSize: fullView.fpx(8)
                            font.family: Kirigami.Theme.fixedWidthFont.family
                            color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.85)
                            Layout.fillWidth: true
                            wrapMode: Text.WrapAnywhere
                            selectionColor: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.35)
                        }

                        ToolButton {
                            icon.name: "edit-copy"
                            implicitWidth: 22
                            implicitHeight: 22
                            ToolTip.text: i18n("Copy SRI hash")
                            ToolTip.visible: hovered
                            ToolTip.delay: 400
                            onClicked: fullView.copyToClipboard(sriField.text)
                        }
                    }

                    // ── Nix snippet ───────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: hashResultField.text !== "" && !hashResultField.isError

                        Text {
                            text: i18n("Nix snippet:")
                            color: fullView.textColor
                            opacity: 0.45
                            font.pixelSize: fullView.fpx(8)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: snippetEdit.implicitHeight + 12
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.22)
                            border.color: Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1

                            RowLayout {
                                anchors {
                                    fill: parent
                                    margins: 6
                                }
                                spacing: 6

                                TextEdit {
                                    id: snippetEdit
                                    Layout.fillWidth: true
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: Text.WrapAnywhere
                                    font.pixelSize: fullView.fpx(8)
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                    color: fullView.textColor
                                    opacity: 0.85
                                    selectionColor: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.35)

                                    text: {
                                        if (hashResultField.text === "" || hashResultField.isError)
                                            return "";
                                        const h = hashResultField.text;
                                        const input = hashInputField.text.trim();
                                        switch (hashModeHolder.value) {
                                        case "url":
                                            return 'fetchurl {\n  url = "' + input + '";\n  sha256 = "' + h + '";\n}';
                                        case "zip":
                                            return 'fetchzip {\n  url = "' + input + '";\n  sha256 = "' + h + '";\n}';
                                        case "github":
                                            {
                                                const parts = input.split("/");
                                                return 'fetchFromGitHub {\n  owner = "' + (parts[0] || "") + '";\n  repo  = "' + (parts[1] || "") + '";\n  rev   = "' + (parts.slice(2).join("/") || "") + '";\n  sha256 = "' + h + '";\n}';
                                            }
                                        case "file":
                                        case "store":
                                            return '# sha256: ' + h;
                                        default:
                                            return h;
                                        }
                                    }
                                }

                                ToolButton {
                                    icon.name: "edit-copy"
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    Layout.alignment: Qt.AlignTop
                                    ToolTip.text: i18n("Copy snippet")
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 400
                                    onClicked: fullView.copyToClipboard(snippetEdit.text)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Text {
                        text: i18n("nix-prefetch-url must be available on PATH. GitHub mode fetches the archive tarball.")
                        color: fullView.textColor
                        opacity: 0.28
                        font.pixelSize: fullView.fpx(8)
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // React to hashResult pushed back from main
                Connections {
                    target: fullView
                    function onHashResultChanged() {
                        const r = fullView.hashResult;
                        if (r === null)
                            return;
                        hashSpinner.visible = false;
                        hashResultField.isError = r.isError;
                        hashResultField.text = r.value;
                    }
                }
            }
        }
    }

    // ── Floating toast overlay ────────────────────────────────────────────────
    // Anchored to FullView bottom-right so toasts float above content instead of
    // pushing it down. Newest toast appears at the bottom; older ones stack up.
    ColumnLayout {
        id: toastOverlay
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: fullView.showBg ? 16 : 8
        anchors.bottomMargin: fullView.showBg ? 16 : 8
        width: Math.min(340, parent.width - (fullView.showBg ? 32 : 16))
        spacing: 6
        z: 100

        Repeater {
            model: fullView.toasts
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: toastLayout.implicitHeight + 12
                radius: 6
                color: modelData.err ? Qt.rgba(0.20, 0.04, 0.04, 0.92) : Qt.rgba(0.04, 0.16, 0.06, 0.92)
                border.color: modelData.err ? "#ff5555" : "#55cc55"
                border.width: 1
                clip: true
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }

                RowLayout {
                    id: toastLayout
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    Kirigami.Icon {
                        source: modelData.err ? "dialog-error" : "dialog-ok"
                        implicitWidth: 16
                        implicitHeight: 16
                        color: modelData.err ? "#ff5555" : "#55cc55"
                        Layout.alignment: Qt.AlignTop
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.msg
                        color: fullView.textColor
                        font.pixelSize: fullView.fpx(9)
                        wrapMode: Text.Wrap
                        maximumLineCount: 6
                        elide: Text.ElideRight
                    }
                    ToolButton {
                        visible: !!modelData.err
                        icon.name: "edit-copy"
                        implicitWidth: 20
                        implicitHeight: 20
                        Layout.alignment: Qt.AlignTop
                        ToolTip.text: i18n("Copy error message")
                        ToolTip.visible: hovered
                        ToolTip.delay: 600
                        onClicked: fullView.copyToClipboard(modelData.msg)
                    }
                    ToolButton {
                        icon.name: "window-close"
                        implicitWidth: 20
                        implicitHeight: 20
                        Layout.alignment: Qt.AlignTop
                        onClicked: fullView.dismissToast(index)
                    }
                }
            }
        }
    }
}
