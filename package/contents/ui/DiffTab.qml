import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "components"

Item {
    id: diffTab

    // ── Required properties ───────────────────────────────────────────────────
    required property color accentColor
    required property color textColor
    required property real fs
    required property var generations
    required property var detailsCache
    required property var pairDiffCache
    required property bool isLoadingPairDiff
    required property string diffViewMode
    required property var iconCache
    required property var metaCache
    required property bool showPackageIcons
    required property string activeViewMode

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }
    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * Kirigami.Theme.smallFont.pixelSize * fs));
    }

    signal compareRequested(int genA, int genB)
    signal copyToClipboard(string text)
    signal diffViewModePicked(string mode)

    // Exposed aliases so parent can pre-populate picker selection
    property alias pickerA: pickerA
    property alias pickerB: pickerB

    anchors.fill: parent
    visible: activeViewMode === "diff"

    property int genA: generations.length > 0 ? generations[0].number : -1
    property int genB: generations.length > 1 ? generations[1].number : -1

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Picker row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: i18n("Compare:")
                color: diffTab.textColor
                opacity: 0.6
                font.pixelSize: diffTab.fpx(10)
            }

            // ── Custom picker A ───────────────────────────────────
            Item {
                id: pickerA
                implicitWidth: 86
                implicitHeight: 26
                property int selectedIndex: 0
                property bool open: false

                onSelectedIndexChanged: {
                    if (diffTab.generations.length > selectedIndex)
                        diffTab.genA = diffTab.generations[selectedIndex].number;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: pickerA.open ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.14) : (pickerAMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
                    border.color: pickerA.open ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.15)
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
                    text: diffTab.generations.length > pickerA.selectedIndex ? "#" + diffTab.generations[pickerA.selectedIndex].number : "—"
                    color: diffTab.textColor
                    font.pixelSize: diffTab.fpx(9)
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
                    color: diffTab.textColor
                    opacity: 0.45
                    font.pixelSize: diffTab.fpx(7)
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
                        border.color: Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.35)
                        border.width: 1
                    }
                    contentItem: ListView {
                        implicitHeight: Math.min(contentHeight, 200)
                        clip: true
                        model: diffTab.generations
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                        delegate: Rectangle {
                            width: popupA.width - 8
                            height: 26
                            radius: 4
                            color: pickerA.selectedIndex === index ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.25) : (rowMaA.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
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
                                color: diffTab.textColor
                                font.pixelSize: diffTab.fpx(9)
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
                color: diffTab.textColor
                opacity: 0.45
                font.pixelSize: diffTab.fpx(10)
            }

            // ── Custom picker B ───────────────────────────────────
            Item {
                id: pickerB
                implicitWidth: 86
                implicitHeight: 26
                property int selectedIndex: Math.min(1, diffTab.generations.length - 1)
                property bool open: false

                onSelectedIndexChanged: {
                    if (diffTab.generations.length > selectedIndex)
                        diffTab.genB = diffTab.generations[selectedIndex].number;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: pickerB.open ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.14) : (pickerBMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
                    border.color: pickerB.open ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.15)
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
                    text: diffTab.generations.length > pickerB.selectedIndex ? "#" + diffTab.generations[pickerB.selectedIndex].number : "—"
                    color: diffTab.textColor
                    font.pixelSize: diffTab.fpx(9)
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
                    color: diffTab.textColor
                    opacity: 0.45
                    font.pixelSize: diffTab.fpx(7)
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
                        border.color: Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.35)
                        border.width: 1
                    }
                    contentItem: ListView {
                        implicitHeight: Math.min(contentHeight, 200)
                        clip: true
                        model: diffTab.generations
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                        delegate: Rectangle {
                            width: popupB.width - 8
                            height: 26
                            radius: 4
                            color: pickerB.selectedIndex === index ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.25) : (rowMaB.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
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
                                color: diffTab.textColor
                                font.pixelSize: diffTab.fpx(9)
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
                readonly property bool active: diffTab.genA !== diffTab.genB && diffTab.genA > 0 && diffTab.genB > 0 && !diffTab.isLoadingPairDiff
                implicitHeight: 26
                implicitWidth: compareRow.implicitWidth + 20
                radius: 6

                color: active ? (compareMa.containsMouse ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.25) : Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.12)) : Qt.rgba(1, 1, 1, 0.04)

                border.color: active ? (compareMa.containsMouse ? diffTab.accentColor : Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.5)) : Qt.rgba(1, 1, 1, 0.08)
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
                        source: diffTab.svg("ic_diff")
                        isMask: true
                        implicitWidth: 12
                        implicitHeight: 12
                        color: compareBtn.active ? diffTab.accentColor : Qt.rgba(diffTab.textColor.r, diffTab.textColor.g, diffTab.textColor.b, 0.3)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }

                    Text {
                        text: diffTab.isLoadingPairDiff ? i18n("Loading…") : i18n("Compare")
                        color: compareBtn.active ? diffTab.accentColor : Qt.rgba(diffTab.textColor.r, diffTab.textColor.g, diffTab.textColor.b, 0.3)
                        font.pixelSize: diffTab.fpx(9)
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
                            diffTab.compareRequested(diffTab.genA, diffTab.genB);
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
                return !!(diffTab.pairDiffCache[k]);
            }
            height: metaRow.implicitHeight + 14
            radius: 6
            color: Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.07)
            border.color: Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.20)
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
                        color: diffTab.textColor
                        opacity: 0.35
                        font.pixelSize: diffTab.fpx(6.5)
                        font.bold: true
                        font.letterSpacing: 1.0
                    }
                    Text {
                        text: "#" + diffTab.genB + (diffTab.detailsCache[diffTab.genB] ? "  ·  " + diffTab.detailsCache[diffTab.genB].nixosVer : "")
                        color: diffTab.textColor
                        font.pixelSize: diffTab.fpx(9)
                        font.bold: true
                    }
                    Text {
                        visible: !!(diffTab.detailsCache[diffTab.genB] && diffTab.detailsCache[diffTab.genB].commitDate)
                        text: diffTab.detailsCache[diffTab.genB] ? diffTab.detailsCache[diffTab.genB].commitDate : ""
                        color: diffTab.textColor
                        opacity: 0.38
                        font.pixelSize: diffTab.fpx(7.5)
                        font.family: Kirigami.Theme.fixedWidthFont.family
                    }
                }

                Text {
                    text: "→"
                    color: diffTab.accentColor
                    font.pixelSize: diffTab.fpx(13)
                    font.bold: true
                    opacity: 0.8
                }

                // B gen info (TO = genA)
                Column {
                    spacing: 1
                    Layout.fillWidth: true
                    Text {
                        text: i18n("TO")
                        color: diffTab.textColor
                        opacity: 0.35
                        font.pixelSize: diffTab.fpx(6.5)
                        font.bold: true
                        font.letterSpacing: 1.0
                    }
                    Text {
                        text: "#" + diffTab.genA + (diffTab.detailsCache[diffTab.genA] ? "  ·  " + diffTab.detailsCache[diffTab.genA].nixosVer : "")
                        color: diffTab.textColor
                        font.pixelSize: diffTab.fpx(9)
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        visible: !!(diffTab.detailsCache[diffTab.genA] && diffTab.detailsCache[diffTab.genA].commitDate)
                        text: diffTab.detailsCache[diffTab.genA] ? diffTab.detailsCache[diffTab.genA].commitDate : ""
                        color: diffTab.textColor
                        opacity: 0.38
                        font.pixelSize: diffTab.fpx(7.5)
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
                                const e = diffTab.pairDiffCache[k];
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
                                font.pixelSize: diffTab.fpx(7.5)
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
                    const e = diffTab.pairDiffCache[k];
                    return !!(e && e.diff.length > 0);
                }
                height: 16
                radius: 8
                width: totalLbl.implicitWidth + 12
                color: Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.18)
                border.color: Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.50)
                border.width: 1
                Text {
                    id: totalLbl
                    anchors.centerIn: parent
                    text: {
                        const k = diffTab.genA + "_" + diffTab.genB;
                        const e = diffTab.pairDiffCache[k];
                        return e ? e.diff.length + " " + i18n("packages") : "";
                    }
                    color: diffTab.accentColor
                    font.pixelSize: diffTab.fpx(7.5)
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
                                icon: diffTab.svg("ic_timeline"),
                                tip: i18n("Compact view")
                            },
                            {
                                id: "detailed",
                                icon: diffTab.svg("ic_diff"),
                                tip: i18n("Detailed view")
                            }
                        ]
                        Rectangle {
                            readonly property bool active: diffTab.diffViewMode === modelData.id
                            width: 28
                            height: 20
                            radius: 4
                            color: active ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.28) : (modePillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            border.color: active ? Qt.rgba(diffTab.accentColor.r, diffTab.accentColor.g, diffTab.accentColor.b, 0.55) : "transparent"
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
                                color: parent.active ? diffTab.accentColor : Qt.rgba(diffTab.textColor.r, diffTab.textColor.g, diffTab.textColor.b, 0.50)
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
                                onClicked: diffTab.diffViewModePicked(modelData.id)
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
                    const entry = diffTab.pairDiffCache[diffTabView.pairKey];
                    return entry ? entry.diff : [];
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    visible: diffTabView.count === 0
                    text: diffTab.isLoadingPairDiff ? i18n("Computing diff…") : (diffTab.genA > 0 && diffTab.genA === diffTab.genB ? i18n("Select two different generations") : (diffTab.pairDiffCache[diffTabView.pairKey] ? i18n("No package differences") : i18n("Pick two generations and click Compare")))
                    color: diffTab.textColor
                    opacity: 0.40
                    font.pixelSize: diffTab.fpx(10)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                delegate: PackageRow {
                    width: diffTabView.width
                    pkg: modelData
                    accentColor: diffTab.accentColor
                    textColor: diffTab.textColor
                    fs: diffTab.fs
                    forceExpanded: diffTab.diffViewMode === "detailed"
                    iconCache: diffTab.iconCache
                    metaCache: diffTab.metaCache
                    showPackageIcons: diffTab.showPackageIcons
                    onCopyRequested: text => diffTab.copyToClipboard(text)
                }
            }
        }
    }
}
