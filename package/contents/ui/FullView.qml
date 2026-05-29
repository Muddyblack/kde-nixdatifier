import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
    property string gcCustomCommand: ""
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
        // Sync the picker selectedIndex values so the dropdown labels update.
        // The pickers drive genA/genB via onSelectedIndexChanged, so we must
        // set selectedIndex rather than (only) writing genA/genB directly.
        for (var i = 0; i < fullView.generations.length; i++) {
            if (fullView.generations[i].number === genA)
                diffTab.pickerA.selectedIndex = i;
            if (fullView.generations[i].number === genB)
                diffTab.pickerB.selectedIndex = i;
        }
        fullView.viewModeChanged("diff");
        fullView.compareRequested(genA, genB);
    }

    // Pending action for inline confirm bar
    property int pendingGenNum: -1
    property string pendingAction: ""
    property bool usePkexec: false
    property string pendingCleanup: ""

    // Pairwise diff state for the Diff tab
    property var pairDiffCache: ({})
    property bool isLoadingPairDiff: false
    property var configDiffCache: ({})
    property var dryRunCache: ({})
    property bool isDryRunning: false
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
    signal cleanupVariantPicked(string mode)
    signal confirmCleanup(string mode)
    signal cancelCleanup
    signal compareRequested(int genA, int genB)
    signal dryRunRequested(string inputName, string overrideRef)
    signal updateInputRequested(string inputName)
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

            // Row 1: logo + Title/Gen on the left, Disk pool size on the right
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Nix Logo
                Kirigami.Icon {
                    source: Qt.resolvedUrl("nixos-logo.svg")
                    implicitWidth: 26
                    implicitHeight: 26
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

                // Title + Generation/Date
                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: i18n("Nixdatifier")
                        color: fullView.textColor
                        font.pixelSize: fullView.fpx(14)
                        font.bold: true
                        font.letterSpacing: 0.2
                    }

                    RowLayout {
                        spacing: 4
                        Rectangle {
                            visible: fullView.activeGenNum > 0
                            radius: 9
                            color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.14)
                            border.color: Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.30)
                            border.width: 1
                            implicitWidth: pillText.implicitWidth + 10
                            implicitHeight: 15
                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: "#" + fullView.activeGenNum
                                color: fullView.accentColor
                                font.pixelSize: fullView.fpx(7.5)
                                font.bold: true
                                font.letterSpacing: 0.3
                            }
                        }
                        Text {
                            visible: fullView.activeGenNum > 0 && fullView.nixosVersion !== ""
                            text: {
                                const ver = fullView.nixosVersion;
                                const m = ver.match(/^(\d{2}\.\d{2}\.\d{4})/);
                                return m ? m[1] : ver;
                            }
                            color: fullView.textColor
                            opacity: 0.4
                            font.pixelSize: fullView.fpx(8)
                            font.family: Kirigami.Theme.fixedWidthFont.family
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Storage Stat highlighted clean on the right
                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignVCenter
                    visible: fullView.diskStoreBytes > 0

                    Text {
                        text: i18n("TOTAL POOL")
                        color: fullView.textColor
                        opacity: 0.4
                        font.pixelSize: fullView.fpx(7)
                        font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }
                    Text {
                        text: fullView.formatBytes(fullView.diskStoreBytes)
                        color: Qt.color("#f5c2e7") // Rosewater/Pink accent
                        font.pixelSize: fullView.fpx(11.5)
                        font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        ToolTip.text: i18n("/nix/store: %1\nReclaimable via GC: %2\n/nix free space: %3").arg(fullView.formatBytes(fullView.diskStoreBytes)).arg(fullView.formatBytes(fullView.diskReclaimableBytes)).arg(fullView.formatBytes(fullView.diskFreeBytes))
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }
            }

            // Thin horizontal divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            // Row 2: Secondary Metadata + options/pin buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Hostname
                    RowLayout {
                        spacing: 4
                        visible: fullView.hostname !== ""
                        Text {
                            text: "👤"
                            font.pixelSize: fullView.fpx(8.5)
                            opacity: 0.5
                        }
                        Text {
                            text: fullView.hostname
                            color: fullView.textColor
                            opacity: 0.7
                            font.pixelSize: fullView.fpx(8.5)
                            font.bold: true
                        }
                    }

                    // Divider dot
                    Rectangle {
                        visible: fullView.hostname !== "" && fullView.uptime !== ""
                        width: 3
                        height: 3
                        radius: 1.5
                        color: fullView.textColor
                        opacity: 0.25
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Uptime
                    RowLayout {
                        spacing: 4
                        visible: fullView.uptime !== ""
                        Text {
                            text: "⏱️"
                            font.pixelSize: fullView.fpx(8.5)
                            opacity: 0.5
                        }
                        Text {
                            text: i18n("up %1").arg(fullView.uptime)
                            color: fullView.textColor
                            opacity: 0.55
                            font.pixelSize: fullView.fpx(8.5)
                        }
                    }

                    // Divider dot
                    Rectangle {
                        visible: fullView.uptime !== "" && fullView.lastActivationTime !== ""
                        width: 3
                        height: 3
                        radius: 1.5
                        color: fullView.textColor
                        opacity: 0.25
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Switched/Activation
                    RowLayout {
                        spacing: 4
                        visible: fullView.lastActivationTime !== ""
                        Text {
                            text: "📅"
                            font.pixelSize: fullView.fpx(8.5)
                            opacity: 0.5
                        }
                        Text {
                            text: i18n("switched %1").arg(fullView.lastActivationTime)
                            color: fullView.textColor
                            opacity: 0.55
                            font.pixelSize: fullView.fpx(8.5)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                // Pin button
                Rectangle {
                    id: pinBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 5
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
                        font.pixelSize: 14
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

                // Cleanup button
                Rectangle {
                    id: cleanupBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 5
                    color: cleanupMa.containsMouse || cleanupMenu.opened ? Qt.rgba(1, 0.45, 0.45, 0.14) : Qt.rgba(1, 1, 1, 0.03)
                    border.color: cleanupMa.containsMouse || cleanupMenu.opened ? Qt.rgba(1, 0.45, 0.45, 0.55) : Qt.rgba(1, 1, 1, 0.08)
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

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "edit-clear-all"
                        implicitWidth: 13
                        implicitHeight: 13
                        isMask: true
                        color: cleanupMa.containsMouse || cleanupMenu.opened ? "#ff8080" : fullView.textColor
                        opacity: cleanupMa.containsMouse || cleanupMenu.opened ? 0.90 : 0.50
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 110
                            }
                        }
                    }

                    MouseArea {
                        id: cleanupMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cleanupMenu.opened ? cleanupMenu.close() : cleanupMenu.open()
                        ToolTip.text: i18n("Garbage collect / clean up store")
                        ToolTip.visible: containsMouse && !cleanupMenu.opened
                        ToolTip.delay: 500
                    }

                    Popup {
                        id: cleanupMenu
                        y: cleanupBtn.height + 6
                        x: cleanupBtn.width - implicitWidth
                        padding: 5
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        background: Rectangle {
                            color: Qt.rgba(0.06, 0.06, 0.09, 0.97)
                            radius: 8
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1
                        }

                        contentItem: Column {
                            spacing: 1

                            Text {
                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 2
                                bottomPadding: 4
                                text: i18n("Garbage collect")
                                color: fullView.textColor
                                opacity: 0.35
                                font.pixelSize: fullView.fpx(7.5)
                                font.bold: true
                                font.letterSpacing: 0.5
                            }

                            Repeater {
                                model: {
                                    const base = [
                                        {
                                            label: i18n("GC only"),
                                            sub: i18n("Free unreferenced store paths, keep all generations"),
                                            mode: "gc",
                                            color: "#80b4ff"
                                        },
                                        {
                                            label: i18n("Remove old gens (14 days)"),
                                            sub: i18n("Delete generations older than 14 days, then GC"),
                                            mode: "gc-14d",
                                            color: "#ffb347"
                                        },
                                        {
                                            label: i18n("Remove all old gens"),
                                            sub: i18n("Delete every non-current generation, then GC"),
                                            mode: "gc-all",
                                            color: "#ff8080"
                                        }
                                    ];
                                    if (fullView.gcCustomCommand.trim())
                                        base.push({
                                            label: fullView.gcCustomCommand.trim(),
                                            sub: i18n("Custom command (runs in terminal)"),
                                            mode: "gc-custom",
                                            color: "#b8a0ff"
                                        });
                                    return base;
                                }

                                delegate: Rectangle {
                                    required property var modelData
                                    width: gcItemCol.implicitWidth + 24
                                    height: 46
                                    radius: 5
                                    color: gcMa.containsMouse ? Qt.rgba(0.15, 0.15, 0.20, 0.80) : "transparent"
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 80
                                        }
                                    }

                                    Column {
                                        id: gcItemCol
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                        }
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 2

                                        Text {
                                            text: modelData.label
                                            color: modelData.color
                                            font.pixelSize: fullView.fpx(9)
                                            font.bold: true
                                        }
                                        Text {
                                            text: modelData.sub
                                            color: fullView.textColor
                                            opacity: 0.45
                                            font.pixelSize: fullView.fpx(7.5)
                                        }
                                    }

                                    MouseArea {
                                        id: gcMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            cleanupMenu.close();
                                            fullView.cleanupVariantPicked(modelData.mode);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Overflow menu button (more options)
                Rectangle {
                    id: overflowBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 5
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
                        anchors.verticalCenterOffset: -2
                        text: "⋯"
                        color: fullView.textColor
                        opacity: 0.75
                        font.pixelSize: 14
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
                    Popup {
                        id: overflowMenu
                        y: overflowBtn.height + 6
                        x: overflowBtn.width - implicitWidth
                        padding: 5
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        background: Rectangle {
                            color: Qt.rgba(0.06, 0.06, 0.09, 0.97)
                            radius: 8
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1
                        }

                        contentItem: Column {
                            spacing: 1

                            Repeater {
                                model: [
                                    {
                                        label: fullView.isLoadingGens ? i18n("Refreshing…") : i18n("Refresh generations list"),
                                        icon: "view-refresh",
                                        enabled: !fullView.isLoadingGens,
                                        visible: true,
                                        action: "refresh"
                                    },
                                    {
                                        label: fullView.isCheckingFlake ? i18n("Checking flake…") : i18n("Check flake for updates"),
                                        icon: "view-refresh",
                                        enabled: !fullView.isCheckingFlake,
                                        visible: fullView.showFlakeSection,
                                        action: "flake"
                                    },
                                    {
                                        label: i18n("Configure widget…"),
                                        icon: "configure",
                                        enabled: true,
                                        visible: true,
                                        action: "configure"
                                    },
                                    {
                                        label: i18n("KDE Store Page"),
                                        icon: "kde",
                                        enabled: true,
                                        visible: true,
                                        action: "store"
                                    },
                                    {
                                        label: i18n("GitHub Repository"),
                                        icon: "vcs-code-collaborator",
                                        enabled: true,
                                        visible: true,
                                        action: "github"
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    visible: modelData.visible
                                    height: modelData.visible ? 30 : 0
                                    width: menuItemRow.implicitWidth + 24
                                    radius: 5
                                    color: itemMa.containsMouse && modelData.enabled ? Qt.rgba(fullView.accentColor.r, fullView.accentColor.g, fullView.accentColor.b, 0.15) : "transparent"
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 80
                                        }
                                    }

                                    RowLayout {
                                        id: menuItemRow
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Kirigami.Icon {
                                            source: modelData.icon
                                            implicitWidth: 14
                                            implicitHeight: 14
                                            isMask: true
                                            color: fullView.textColor
                                            opacity: modelData.enabled ? 0.70 : 0.28
                                        }
                                        Text {
                                            text: modelData.label
                                            color: fullView.textColor
                                            opacity: modelData.enabled ? 0.85 : 0.35
                                            font.pixelSize: fullView.fpx(8.5)
                                        }
                                    }

                                    MouseArea {
                                        id: itemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: modelData.enabled
                                        cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            overflowMenu.close();
                                            const a = modelData.action;
                                            if (a === "refresh")
                                                fullView.refreshRequested();
                                            else if (a === "flake")
                                                fullView.checkFlakeRequested();
                                            else if (a === "configure")
                                                fullView.configureRequested();
                                            else if (a === "store")
                                                Qt.openUrlExternally("https://store.kde.org/p/2360222/");
                                            else if (a === "github")
                                                Qt.openUrlExternally("https://github.com/Muddyblack/kde-nixdatifier");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Row 3: command buttons (expanded full width, only shown when configured)
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                visible: fullView.showCommandButtons && fullView.customCommands.length > 0

                Repeater {
                    model: fullView.showCommandButtons ? fullView.customCommands.slice(0, 4) : []
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string btnLabel: modelData.label || modelData.cmd || ""
                        readonly property string btnCmd: modelData.cmd || ""
                        readonly property color btnColor: fullView.accentColor

                        visible: btnLabel !== "" && btnCmd !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: btnMa.containsMouse ? Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.25) : Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.10)
                        border.color: btnMa.containsMouse ? Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.60) : Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.30)
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
                            id: btnLabelText
                            anchors.centerIn: parent
                            text: btnLabel
                            color: btnColor
                            font.pixelSize: fullView.fpx(10)
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

        // ── Cleanup confirm bar ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: fullView.pendingCleanup !== ""
            implicitHeight: visible ? gcConfirmCol.implicitHeight + 14 : 0
            radius: 6
            color: Qt.rgba(1, 0.50, 0.25, 0.10)
            border.color: "#ff9944"
            border.width: 1
            clip: true

            ColumnLayout {
                id: gcConfirmCol
                anchors.fill: parent
                anchors.margins: 7
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Kirigami.Icon {
                        source: "edit-clear-all"
                        implicitWidth: 18
                        implicitHeight: 18
                        isMask: true
                        color: "#ff9944"
                        Layout.alignment: Qt.AlignTop
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: fullView.textColor
                        font.pixelSize: fullView.fpx(10)
                        text: {
                            const pw = fullView.usePkexec ? i18n("  A password prompt will appear.") : "";
                            if (fullView.pendingCleanup === "gc")
                                return i18n("Run nix-collect-garbage? Unreferenced store paths will be freed. Generations are kept.") + pw;
                            if (fullView.pendingCleanup === "gc-14d")
                                return i18n("Delete generations older than 14 days and run GC? This cannot be undone.") + pw;
                            return i18n("Delete ALL non-current generations and run GC? This cannot be undone.") + pw;
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
                        text: i18n("Cancel")
                        implicitHeight: 26
                        font.pixelSize: fullView.fpx(9)
                        onClicked: fullView.cancelCleanup()
                        background: Rectangle {
                            radius: 4
                            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: Qt.rgba(1, 1, 1, 0.20)
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: fullView.textColor
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 12
                            rightPadding: 12
                        }
                    }
                    Button {
                        text: i18n("Run")
                        implicitHeight: 26
                        font.pixelSize: fullView.fpx(9)
                        font.bold: true
                        onClicked: fullView.confirmCleanup(fullView.pendingCleanup)
                        background: Rectangle {
                            radius: 4
                            color: parent.hovered ? Qt.rgba(1, 0.60, 0.25, 0.35) : Qt.rgba(1, 0.60, 0.25, 0.20)
                            border.color: "#ff9944"
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: fullView.textColor
                            font: parent.font
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

            TimelineTab {
                id: timelineTab
                anchors.fill: parent
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                timelineColor: fullView.timelineColor
                textColor: fullView.textColor
                fs: fullView.fs
                isLoadingGens: fullView.isLoadingGens
                isLoadingDetails: fullView.isLoadingDetails
                isBusy: fullView.isBusy
                generations: fullView.generations
                selectedGenNum: fullView.selectedGenNum
                bootedGenNum: fullView.bootedGenNum
                detailsCache: fullView.detailsCache
                diffFilter: fullView.diffFilter
                diffMode: fullView.diffMode
                showDeleteButton: fullView.showDeleteButton
                diffFilterEnabled: fullView.diffFilterEnabled
                iconCache: fullView.iconCache
                metaCache: fullView.metaCache
                showPackageIcons: fullView.showPackageIcons
                iconStyle: fullView.iconStyle
                configDiffCache: fullView.configDiffCache

                onSelectGen: n => fullView.selectGen(n)
                onCollapseGen: () => fullView.collapseGen()
                onRequestAction: (n, a) => fullView.requestAction(n, a)
                onDiffModeToggle: n => fullView.diffModeToggle(n)
                onFilterChanged: t => fullView.filterChanged(t)
                onCopyToClipboard: t => fullView.copyToClipboard(t)
                onCompareWithRequested: (a, b) => fullView.openCompareInDiffTab(a, b)
                onRefreshRequested: () => fullView.refreshRequested()
                onConfigureRequested: () => fullView.configureRequested()
            }

            UpdatesTab {
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                textColor: fullView.textColor
                fs: fullView.fs
                isCheckingFlake: fullView.isCheckingFlake
                flakeUpdates: fullView.flakeUpdates
                lastFlakeCheckTime: fullView.lastFlakeCheckTime
                dryRunCache: fullView.dryRunCache
                isDryRunning: fullView.isDryRunning
                iconStyle: fullView.iconStyle

                onDryRunRequested: (inputName, overrideRef) => fullView.dryRunRequested(inputName, overrideRef)
                onUpdateInputRequested: inputName => fullView.updateInputRequested(inputName)
                onDryRunCacheCleared: inputName => {
                    var c = Object.assign({}, fullView.dryRunCache);
                    delete c[inputName];
                    fullView.dryRunCache = c;
                }
            }

            DiffTab {
                id: diffTab
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                textColor: fullView.textColor
                fs: fullView.fs
                generations: fullView.generations
                detailsCache: fullView.detailsCache
                pairDiffCache: fullView.pairDiffCache
                isLoadingPairDiff: fullView.isLoadingPairDiff
                diffViewMode: fullView.diffViewMode
                iconCache: fullView.iconCache
                metaCache: fullView.metaCache
                showPackageIcons: fullView.showPackageIcons

                onCompareRequested: (a, b) => fullView.compareRequested(a, b)
                onCopyToClipboard: t => fullView.copyToClipboard(t)
                onDiffViewModePicked: mode => fullView.diffViewMode = mode
            }

            SecretsTab {
                activeViewMode: fullView.activeViewMode
                textColor: fullView.textColor
                fs: fullView.fs
                deployedSecrets: fullView.deployedSecrets
                sourceSecrets: fullView.sourceSecrets
            }

            HashTab {
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                textColor: fullView.textColor
                fs: fullView.fs
                iconStyle: fullView.iconStyle
                hashResult: fullView.hashResult

                onHashRequested: (mode, input) => fullView.hashRequested(mode, input)
                onCopyToClipboard: t => fullView.copyToClipboard(t)
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
