import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami as Kirigami
import "components"

Item {
    id: genDelegate

    property var gen: ({})
    property color accentColor: "transparent"
    property color timelineColor: "transparent"
    property color textColor: "white"
    property real fs: 1.0
    property int selectedGenNum: -1
    property bool isLoadingDetails: false
    property bool isBusy: false
    property var detailsCache: ({})
    property string diffFilter: ""
    property string diffMode: "booted"
    property bool showDeleteButton: false
    property bool diffFilterEnabled: true
    property int bootedGenNum: -1
    property var iconCache: ({})
    property bool showPackageIcons: true
    property string iconStyle: "colored"
    // Full generations list, used to populate the right-click "Compare with…" menu.
    property var allGenerations: []

    signal selectGen(int genNum)
    signal collapseGen
    signal requestAction(int genNum, string action)
    signal diffModeToggle(int genNum)
    signal filterChanged(string text)
    signal copyToClipboard(string text)
    signal compareWithRequested(int genA, int genB)

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }

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

    // Theme-aware font sizing. Legacy hardcoded sizes were tuned against a 9px base,
    // so divide by 9 to convert legacy values into multipliers of the system small font.
    readonly property int baseFontPx: Kirigami.Theme.smallFont.pixelSize
    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * baseFontPx * fs));
    }

    readonly property bool isExpanded: gen.number === genDelegate.selectedGenNum
    readonly property bool isCurrent: gen.booted || gen.active
    readonly property int headerH: 40
    readonly property color statusColor: gen.booted ? "#3ddc84" : (gen.active ? "#ffb74d" : Qt.rgba(1, 1, 1, 0.22))

    // Expanded height: header + compact meta strip (28) + divider (1) + diff header (26) + list.
    // List height tracks the ListView's contentHeight so it handles per-row expansion correctly,
    // with a minimum floor for the empty/loading state and a cap so it doesn't dominate the popup.
    property int diffContentH: 0
    readonly property int listH: Math.max(50, Math.min(270, diffContentH + 8))
    readonly property int expandedExtra: 28 + 1 + 26 + listH
    height: isExpanded ? headerH + expandedExtra : headerH
    Behavior on height {
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutCubic
        }
    }

    // ── Timeline rail — shares the same left edge as the card left margin ──────
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: genDelegate.isCurrent ? Qt.rgba(genDelegate.statusColor.r, genDelegate.statusColor.g, genDelegate.statusColor.b, 0.55) : Qt.rgba(genDelegate.timelineColor.r, genDelegate.timelineColor.g, genDelegate.timelineColor.b, 0.18)
    }

    // ── Node dot ──────────────────────────────────────────────────────────────
    Rectangle {
        id: nodeDot
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: Math.round((genDelegate.headerH - 10) / 2)
        width: 10
        height: 10
        radius: 5
        color: genDelegate.isCurrent ? genDelegate.statusColor : Qt.rgba(genDelegate.timelineColor.r, genDelegate.timelineColor.g, genDelegate.timelineColor.b, 0.55)
        border.color: Qt.rgba(0, 0, 0, 0.3)
        border.width: 1

        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 20
            radius: 10
            color: "transparent"
            border.color: nodeDot.color
            border.width: 1.5
            visible: gen.booted
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0.75
                    to: 0.10
                    duration: 1600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.10
                    to: 0.75
                    duration: 1600
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ── Card ──────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors {
            left: parent.left
            leftMargin: 30
            right: parent.right
            rightMargin: 4
            top: parent.top
            topMargin: 2
            bottom: parent.bottom
            bottomMargin: 2
        }
        radius: 7
        color: genDelegate.isExpanded ? Qt.rgba(1, 1, 1, 0.07) : (cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.042) : Qt.rgba(1, 1, 1, 0.015))
        border.color: genDelegate.isExpanded ? Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.38) : (cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05))
        border.width: 1
        clip: true
        Behavior on color {
            ColorAnimation {
                duration: 130
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 130
            }
        }

        // Status accent stripe on left edge
        Rectangle {
            visible: genDelegate.isCurrent
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                topMargin: 4
                bottomMargin: 4
            }
            width: 3
            radius: 1.5
            color: genDelegate.statusColor
            opacity: 0.90
        }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    compareMenu.popup();
                    return;
                }
                if (genDelegate.selectedGenNum === gen.number)
                    genDelegate.collapseGen();
                else
                    genDelegate.selectGen(gen.number);
            }
        }

        // Right-click → Compare with… menu.
        // Lists up to 12 nearby generations (skips the current one).
        Menu {
            id: compareMenu
            Repeater {
                model: {
                    if (!genDelegate.allGenerations || genDelegate.allGenerations.length === 0)
                        return [];
                    const others = genDelegate.allGenerations.filter(g => g.number !== gen.number);
                    return others.slice(0, 12);
                }
                MenuItem {
                    required property var modelData
                    text: {
                        const g = modelData;
                        const d = genDelegate.detailsCache[g.number];
                        const ver = d && d.nixosVer ? "  ·  " + d.nixosVer : "";
                        const flag = g.booted ? "  [booted]" : (g.active ? "  [next]" : "");
                        return i18n("Compare with #%1").arg(g.number) + ver + flag;
                    }
                    onTriggered: genDelegate.compareWithRequested(gen.number, modelData.number)
                }
            }
            MenuSeparator {}
            MenuItem {
                text: i18n("Copy generation number")
                icon.name: "edit-copy"
                onTriggered: genDelegate.copyToClipboard("#" + gen.number)
            }
        }

        // ── Header row ────────────────────────────────────────────────────────
        RowLayout {
            id: headerRow
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            height: genDelegate.headerH
            spacing: 6

            // Gen number
            Text {
                text: "#" + gen.number
                color: genDelegate.isCurrent ? genDelegate.statusColor : genDelegate.textColor
                font.pixelSize: genDelegate.fpx(12)
                font.bold: true
                opacity: genDelegate.isCurrent ? 1.0 : 0.88
            }

            // Timestamp
            Text {
                text: gen.timestamp
                color: genDelegate.textColor
                opacity: 0.35
                font.pixelSize: genDelegate.fpx(8)
                font.family: Kirigami.Theme.fixedWidthFont.family
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // NixOS version (small, right-aligned in header) + copy button
            RowLayout {
                visible: genDelegate.detailsCache[gen.number] !== undefined
                spacing: 3
                Text {
                    id: hdrVerTxt
                    text: genDelegate.detailsCache[gen.number] ? genDelegate.detailsCache[gen.number].nixosVer : ""
                    color: genDelegate.textColor
                    opacity: 0.45
                    font.pixelSize: genDelegate.fpx(8)
                    elide: Text.ElideRight
                    Layout.maximumWidth: 120
                }
                Kirigami.Icon {
                    source: genDelegate.svg("ic_copy")
                    implicitWidth: 11
                    implicitHeight: 11
                    isMask: true
                    color: genDelegate.textColor
                    opacity: hdrCopyMa.containsMouse ? 0.85 : 0.35
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                    MouseArea {
                        id: hdrCopyMa
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            genDelegate.copyToClipboard(hdrVerTxt.text);
                            m.accepted = true;
                        }
                        ToolTip.text: i18n("Copy NixOS version")
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }
            }

            // Loading spinner (replaces nixos ver while loading)
            Kirigami.Icon {
                id: detailsSpinner
                source: Qt.resolvedUrl("nixos-logo.svg")
                isMask: genDelegate.iconStyle !== "colored"
                color: {
                    if (genDelegate.iconStyle === "white")
                        return "#ffffff";
                    if (genDelegate.iconStyle === "black")
                        return "#000000";
                    return genDelegate.accentColor;
                }
                visible: genDelegate.isLoadingDetails && genDelegate.isExpanded && !genDelegate.detailsCache[gen.number]
                implicitWidth: 18
                implicitHeight: 18
                RotationAnimation on rotation {
                    running: detailsSpinner.visible
                    from: 0
                    to: 360
                    duration: 1200
                    loops: Animation.Infinite
                }
            }

            // Status pill
            Rectangle {
                readonly property string label: gen.booted && gen.active ? i18n("ACTIVE") : (gen.booted ? i18n("BOOTED") : (gen.active ? i18n("NEXT BOOT") : ""))
                visible: label !== ""
                radius: 4
                height: 17
                width: pillTxt.implicitWidth + 12
                color: Qt.rgba(genDelegate.statusColor.r, genDelegate.statusColor.g, genDelegate.statusColor.b, 0.14)
                border.color: Qt.rgba(genDelegate.statusColor.r, genDelegate.statusColor.g, genDelegate.statusColor.b, 0.65)
                border.width: 1
                Text {
                    id: pillTxt
                    anchors.centerIn: parent
                    text: parent.label
                    color: genDelegate.statusColor
                    font.pixelSize: genDelegate.fpx(7)
                    font.bold: true
                    font.letterSpacing: 0.6
                }
            }

            // Action icon buttons (only visible when expanded)
            RowLayout {
                visible: genDelegate.isExpanded
                spacing: 3

                // Activate / reboot
                Rectangle {
                    id: actBtn
                    property bool clickable: !gen.booted && !gen.active && !genDelegate.isBusy
                    width: 26
                    height: 22
                    radius: 5
                    color: actMa.containsMouse && clickable ? Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.30) : Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, clickable ? 0.12 : 0.04)
                    border.color: clickable ? Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: gen.booted ? genDelegate.svg("ic_check") : (gen.active ? genDelegate.svg("ic_boot") : genDelegate.svg("ic_activate"))
                        implicitWidth: 12
                        implicitHeight: 12
                        isMask: true
                        color: actBtn.clickable ? genDelegate.accentColor : Qt.rgba(1, 1, 1, 0.30)
                    }
                    MouseArea {
                        id: actMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: actBtn.clickable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: genDelegate.requestAction(gen.number, "switch")
                        ToolTip.text: gen.booted ? i18n("Currently booted") : (gen.active ? i18n("Reboot to apply") : i18n("Activate now (live)"))
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }

                // Next boot
                Rectangle {
                    visible: !gen.booted && !gen.active
                    width: 26
                    height: 22
                    radius: 5
                    color: nbMa.containsMouse && !genDelegate.isBusy ? Qt.rgba(0.55, 0.45, 1, 0.28) : Qt.rgba(0.55, 0.45, 1, 0.10)
                    border.color: Qt.rgba(0.55, 0.45, 1, 0.52)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: genDelegate.svg("ic_nextboot")
                        implicitWidth: 12
                        implicitHeight: 12
                        isMask: true
                        color: genDelegate.textColor
                        opacity: 0.80
                    }
                    MouseArea {
                        id: nbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !genDelegate.isBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: genDelegate.requestAction(gen.number, "rollback")
                        ToolTip.text: i18n("Set as boot target without activating now.")
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }

                // Delete
                Rectangle {
                    visible: genDelegate.showDeleteButton && !gen.active && !gen.booted
                    width: 26
                    height: 22
                    radius: 5
                    color: delMa.containsMouse && !genDelegate.isBusy ? Qt.rgba(1, 0.25, 0.25, 0.30) : Qt.rgba(1, 0.25, 0.25, 0.10)
                    border.color: Qt.rgba(1, 0.35, 0.35, 0.60)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: genDelegate.svg("ic_delete")
                        implicitWidth: 12
                        implicitHeight: 12
                        isMask: true
                        color: "#ff6666"
                    }
                    MouseArea {
                        id: delMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !genDelegate.isBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: genDelegate.requestAction(gen.number, "delete")
                        ToolTip.text: i18n("Delete generation %1 permanently").arg(gen.number)
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }
            }

            // Chevron
            Kirigami.Icon {
                source: genDelegate.isExpanded ? genDelegate.svg("ic_chevron_up") : genDelegate.svg("ic_chevron_down")
                implicitWidth: 14
                implicitHeight: 14
                isMask: true
                color: genDelegate.isExpanded ? genDelegate.accentColor : genDelegate.textColor
                opacity: genDelegate.isExpanded ? 0.85 : (cardHover.containsMouse ? 0.65 : 0.28)
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }

        // ── Expanded panel ────────────────────────────────────────────────────
        Item {
            id: expandPanel
            visible: genDelegate.isExpanded
            opacity: genDelegate.isExpanded ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            anchors {
                left: parent.left
                right: parent.right
                top: headerRow.bottom
                bottom: parent.bottom
                leftMargin: 10
                rightMargin: 6
                bottomMargin: 4
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                // Thin divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.07)
                }

                // ── Compact meta strip: kernel | nixos | commit date | action ──
                RowLayout {
                    Layout.fillWidth: true
                    height: 22
                    spacing: 8

                    // Kernel value
                    RowLayout {
                        spacing: 4
                        Text {
                            text: i18n("kernel")
                            color: genDelegate.textColor
                            opacity: 0.30
                            font.pixelSize: genDelegate.fpx(7.5)
                        }
                        Text {
                            text: genDelegate.detailsCache[gen.number] ? genDelegate.detailsCache[gen.number].kernelVer : "—"
                            color: genDelegate.textColor
                            opacity: 0.75
                            font.pixelSize: genDelegate.fpx(8.5)
                            font.bold: true
                            font.family: Kirigami.Theme.fixedWidthFont.family
                            elide: Text.ElideRight
                            Layout.maximumWidth: 100
                        }
                    }

                    // NixOS version
                    RowLayout {
                        spacing: 4
                        visible: !!(genDelegate.detailsCache[gen.number] && genDelegate.detailsCache[gen.number].nixosVer)
                        Text {
                            text: i18n("nixos")
                            color: genDelegate.textColor
                            opacity: 0.30
                            font.pixelSize: genDelegate.fpx(7.5)
                        }
                        Text {
                            id: metaVerTxt
                            text: genDelegate.detailsCache[gen.number] ? genDelegate.detailsCache[gen.number].nixosVer : ""
                            color: genDelegate.textColor
                            opacity: 0.72
                            font.pixelSize: genDelegate.fpx(8)
                            font.family: Kirigami.Theme.fixedWidthFont.family
                            elide: Text.ElideRight
                            Layout.maximumWidth: 160
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                ToolTip.text: parent.text
                                ToolTip.visible: containsMouse && parent.truncated
                                ToolTip.delay: 300
                            }
                        }
                        Kirigami.Icon {
                            source: genDelegate.svg("ic_copy")
                            implicitWidth: 11
                            implicitHeight: 11
                            isMask: true
                            color: genDelegate.textColor
                            opacity: metaCopyMa.containsMouse ? 0.85 : 0.40
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                            MouseArea {
                                id: metaCopyMa
                                anchors.fill: parent
                                anchors.margins: -3
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: genDelegate.copyToClipboard(metaVerTxt.text)
                                ToolTip.text: i18n("Copy NixOS version")
                                ToolTip.visible: containsMouse
                                ToolTip.delay: 400
                            }
                        }
                    }

                    // Commit date
                    Text {
                        visible: !!(genDelegate.detailsCache[gen.number] && genDelegate.detailsCache[gen.number].commitDate)
                        text: genDelegate.detailsCache[gen.number] ? genDelegate.detailsCache[gen.number].commitDate : ""
                        color: genDelegate.textColor
                        opacity: 0.38
                        font.pixelSize: genDelegate.fpx(7.5)
                        font.family: Kirigami.Theme.fixedWidthFont.family
                    }

                    // Closure size — full /nix/store closure for this generation
                    Rectangle {
                        readonly property string sizeText: genDelegate.detailsCache[gen.number] ? genDelegate.formatBytes(genDelegate.detailsCache[gen.number].closureBytes || 0) : ""
                        visible: sizeText !== ""
                        Layout.preferredWidth: closureLbl.implicitWidth + 12
                        Layout.preferredHeight: 16
                        radius: 8
                        color: Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.10)
                        border.color: Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.30)
                        border.width: 1
                        Text {
                            id: closureLbl
                            anchors.centerIn: parent
                            text: parent.sizeText
                            color: genDelegate.accentColor
                            opacity: 0.85
                            font.pixelSize: genDelegate.fpx(7.5)
                            font.family: Kirigami.Theme.fixedWidthFont.family
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            ToolTip.text: i18n("Total closure size for this generation")
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 400
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Action label (only when relevant)
                    Text {
                        visible: gen.active && !gen.booted
                        text: i18n("→ reboot to apply")
                        color: genDelegate.statusColor
                        opacity: 0.80
                        font.pixelSize: genDelegate.fpx(7.5)
                        font.italic: true
                    }
                    Text {
                        visible: !gen.active && !gen.booted
                        text: i18n("click  ▶  to activate")
                        color: genDelegate.textColor
                        opacity: 0.28
                        font.pixelSize: genDelegate.fpx(7.5)
                    }
                }

                // Thin divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                // ── Diff section header ───────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    height: 22
                    spacing: 5

                    Text {
                        text: {
                            if (gen.booted)
                                return i18n("Changes vs. previous");
                            if (genDelegate.diffMode === "booted" && genDelegate.bootedGenNum > 0)
                                return i18n("vs. booted #%1").arg(genDelegate.bootedGenNum);
                            return i18n("vs. previous");
                        }
                        color: genDelegate.textColor
                        opacity: 0.42
                        font.pixelSize: genDelegate.fpx(8)
                        font.bold: true
                    }

                    // Count badge
                    Rectangle {
                        visible: genDelegate.detailsCache[gen.number] && genDelegate.detailsCache[gen.number].diff.length > 0
                        height: 16
                        width: cntLbl.implicitWidth + 10
                        radius: 8
                        color: Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.18)
                        border.color: Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.50)
                        border.width: 1
                        Text {
                            id: cntLbl
                            anchors.centerIn: parent
                            text: genDelegate.detailsCache[gen.number] ? genDelegate.detailsCache[gen.number].diff.length : "0"
                            color: genDelegate.accentColor
                            font.pixelSize: genDelegate.fpx(7.5)
                            font.bold: true
                        }
                    }

                    // Diff mode toggle
                    Rectangle {
                        visible: !gen.booted && genDelegate.bootedGenNum > 0
                        width: 20
                        height: 17
                        radius: 4
                        color: dmmMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            source: genDelegate.svg("ic_diff")
                            implicitWidth: 11
                            implicitHeight: 11
                            isMask: true
                            color: genDelegate.textColor
                            opacity: 0.50
                        }
                        MouseArea {
                            id: dmmMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: genDelegate.diffModeToggle(gen.number)
                            ToolTip.text: genDelegate.diffMode === "booted" ? i18n("Compare vs. previous") : i18n("Compare vs. booted")
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 400
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Filter input
                    Rectangle {
                        visible: genDelegate.diffFilterEnabled && genDelegate.detailsCache[gen.number] && genDelegate.detailsCache[gen.number].diff.length > 0
                        height: 18
                        width: 110
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: ff.activeFocus ? Qt.rgba(genDelegate.accentColor.r, genDelegate.accentColor.g, genDelegate.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 110
                            }
                        }
                        TextInput {
                            id: ff
                            anchors {
                                fill: parent
                                leftMargin: 7
                                rightMargin: 7
                            }
                            font.pixelSize: genDelegate.fpx(7.5)
                            color: genDelegate.textColor
                            clip: true
                            onTextChanged: genDelegate.filterChanged(text)
                            Text {
                                anchors.fill: parent
                                text: i18n("Filter…")
                                color: genDelegate.textColor
                                opacity: 0.25
                                font.pixelSize: genDelegate.fpx(7.5)
                                visible: ff.text === ""
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // ── Package list ─────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 5
                    color: Qt.rgba(0, 0, 0, 0.20)
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    clip: true

                    ListView {
                        id: diffView
                        anchors.fill: parent
                        anchors.margins: 3
                        clip: true
                        spacing: 1
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                        onContentHeightChanged: genDelegate.diffContentH = contentHeight

                        model: {
                            if (!genDelegate.detailsCache[gen.number])
                                return [];
                            const all = genDelegate.detailsCache[gen.number].diff;
                            const f = genDelegate.diffFilter.toLowerCase();
                            return f ? all.filter(d => d.name.toLowerCase().indexOf(f) !== -1) : all;
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: diffView.count === 0
                            text: genDelegate.isLoadingDetails && !genDelegate.detailsCache[gen.number] ? i18n("Loading…") : (genDelegate.diffFilter ? i18n("No matches") : i18n("No package changes"))
                            color: genDelegate.textColor
                            opacity: 0.32
                            font.pixelSize: genDelegate.fpx(9)
                        }

                        delegate: PackageRow {
                            width: diffView.width
                            pkg: modelData
                            accentColor: genDelegate.accentColor
                            textColor: genDelegate.textColor
                            fs: genDelegate.fs
                            forceExpanded: false
                            iconCache: genDelegate.iconCache
                            showPackageIcons: genDelegate.showPackageIcons
                            onCopyRequested: t => genDelegate.copyToClipboard(t)
                        }
                    }
                }
            }
        }
    }
}
