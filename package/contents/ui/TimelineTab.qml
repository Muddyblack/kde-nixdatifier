import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "components"

Item {
    id: timelineTab

    // ── Required properties ───────────────────────────────────────────────────
    required property color accentColor
    required property color timelineColor
    required property color textColor
    required property real fs
    required property bool isLoadingGens
    required property bool isLoadingDetails
    required property bool isBusy
    required property var generations
    required property int selectedGenNum
    required property int bootedGenNum
    required property var detailsCache
    required property string diffFilter
    required property string diffMode
    required property bool showDeleteButton
    required property bool diffFilterEnabled
    required property var iconCache
    required property var metaCache
    required property bool showPackageIcons
    required property string iconStyle
    required property var configDiffCache
    required property string activeViewMode

    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * Kirigami.Theme.smallFont.pixelSize * fs));
    }

    signal selectGen(int genNum)
    signal collapseGen
    signal requestAction(int genNum, string action)
    signal diffModeToggle(int genNum)
    signal filterChanged(string text)
    signal copyToClipboard(string text)
    signal compareWithRequested(int genA, int genB)
    signal refreshRequested
    signal configureRequested

    visible: activeViewMode === "timeline"
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
        let idx = list.findIndex(g => g.number === timelineTab.selectedGenNum);
        if (idx < 0)
            idx = delta > 0 ? -1 : list.length;
        const next = Math.max(0, Math.min(list.length - 1, idx + delta));
        timelineTab.selectGen(list[next].number);
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
                timelineTab.selectGen(timelineTab.filteredGenerations[0].number);
                genListView.positionViewAtBeginning();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            const list = timelineTab.filteredGenerations;
            if (list.length > 0) {
                timelineTab.selectGen(list[list.length - 1].number);
                genListView.positionViewAtEnd();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (timelineTab.selectedGenNum > 0) {
                // Toggle by re-selecting (handler in main collapses if same).
                timelineTab.collapseGen();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete && timelineTab.selectedGenNum > 0 && timelineTab.showDeleteButton) {
            timelineTab.requestAction(timelineTab.selectedGenNum, "delete");
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
        const d = timelineTab.detailsCache[g.number];
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
            return timelineTab.generations;
        return timelineTab.generations.filter(timelineTab.genMatches);
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
            border.color: timelineSearch.activeFocus ? Qt.rgba(timelineTab.accentColor.r, timelineTab.accentColor.g, timelineTab.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.10)
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
                    color: timelineTab.textColor
                    opacity: 0.45
                    font.pixelSize: timelineTab.fpx(9)
                }
                TextInput {
                    id: timelineSearch
                    Layout.fillWidth: true
                    font.pixelSize: timelineTab.fpx(9)
                    color: timelineTab.textColor
                    clip: true
                    onTextChanged: timelineTab.searchText = text
                    KeyNavigation.priority: KeyNavigation.BeforeItem
                    Keys.onEscapePressed: text = ""

                    Text {
                        anchors.fill: parent
                        visible: timelineSearch.text === ""
                        text: i18n("Search generations, packages, dates…")
                        color: timelineTab.textColor
                        opacity: 0.30
                        font.pixelSize: timelineTab.fpx(9)
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                // Result count
                Text {
                    visible: timelineSearch.text !== ""
                    text: i18n("%1 / %2").arg(timelineTab.filteredGenerations.length).arg(timelineTab.generations.length)
                    color: timelineTab.textColor
                    opacity: 0.45
                    font.pixelSize: timelineTab.fpx(8)
                    font.family: Kirigami.Theme.fixedWidthFont.family
                }
                // Clear button
                Text {
                    visible: timelineSearch.text !== ""
                    text: "×"
                    color: timelineTab.textColor
                    opacity: clearMa.containsMouse ? 0.85 : 0.55
                    font.pixelSize: timelineTab.fpx(12)
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
                accentColor: timelineTab.accentColor
                timelineColor: timelineTab.timelineColor
                textColor: timelineTab.textColor
                fs: timelineTab.fs
                selectedGenNum: timelineTab.selectedGenNum
                isLoadingDetails: timelineTab.isLoadingDetails
                isBusy: timelineTab.isBusy
                detailsCache: timelineTab.detailsCache
                diffFilter: timelineTab.diffFilter
                diffMode: timelineTab.diffMode
                showDeleteButton: timelineTab.showDeleteButton
                diffFilterEnabled: timelineTab.diffFilterEnabled
                bootedGenNum: timelineTab.bootedGenNum
                iconCache: timelineTab.iconCache
                metaCache: timelineTab.metaCache
                showPackageIcons: timelineTab.showPackageIcons
                iconStyle: timelineTab.iconStyle
                allGenerations: timelineTab.generations
                configDiffCache: timelineTab.configDiffCache

                onSelectGen: n => timelineTab.selectGen(n)
                onCollapseGen: () => timelineTab.collapseGen()
                onRequestAction: (n, a) => timelineTab.requestAction(n, a)
                onDiffModeToggle: n => timelineTab.diffModeToggle(n)
                onFilterChanged: t => timelineTab.filterChanged(t)
                onCopyToClipboard: t => timelineTab.copyToClipboard(t)
                onCompareWithRequested: (a, b) => timelineTab.compareWithRequested(a, b)
            }
        }
    }

    // Loading spinner
    Kirigami.Icon {
        id: mainSpinner
        anchors.centerIn: parent
        source: Qt.resolvedUrl("nixos-logo.svg")
        isMask: timelineTab.iconStyle !== "colored"
        color: {
            if (timelineTab.iconStyle === "white")
                return "#ffffff";
            if (timelineTab.iconStyle === "black")
                return "#000000";
            return timelineTab.accentColor;
        }
        visible: timelineTab.isLoadingGens && timelineTab.generations.length === 0
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

        readonly property bool noGenerations: timelineTab.generations.length === 0 && !timelineTab.isLoadingGens
        readonly property bool noMatches: timelineTab.generations.length > 0 && timelineTab.filteredGenerations.length === 0 && timelineTab.searchText.trim() !== ""

        visible: noGenerations || noMatches

        Kirigami.Icon {
            source: parent.noMatches ? "edit-find" : "dialog-warning"
            implicitWidth: 44
            implicitHeight: 44
            opacity: 0.40
            anchors.horizontalCenter: parent.horizontalCenter
            color: timelineTab.accentColor
            isMask: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.noMatches ? i18n("No matches") : i18n("No generations found")
            color: timelineTab.textColor
            opacity: 0.85
            font.pixelSize: timelineTab.fpx(12)
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            Layout.fillWidth: true
            width: parent.width
            text: parent.noMatches ? i18n("Nothing matches \"%1\". Try a partial package name, a generation number, or a date.").arg(timelineTab.searchText) : i18n("Check that /nix/var/nix/profiles/ exists and is readable. If you just installed NixOS you should have at least one generation — try refreshing.")
            color: timelineTab.textColor
            opacity: 0.55
            font.pixelSize: timelineTab.fpx(9)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Button {
                visible: parent.parent.noMatches
                text: i18n("Clear search")
                font.pixelSize: timelineTab.fpx(9)
                onClicked: timelineSearch.text = ""
            }
            Button {
                visible: !parent.parent.noMatches
                text: i18n("Refresh")
                font.pixelSize: timelineTab.fpx(9)
                onClicked: timelineTab.refreshRequested()
            }
            Button {
                visible: !parent.parent.noMatches
                text: i18n("Configure…")
                font.pixelSize: timelineTab.fpx(9)
                onClicked: timelineTab.configureRequested()
            }
        }
    }
}
