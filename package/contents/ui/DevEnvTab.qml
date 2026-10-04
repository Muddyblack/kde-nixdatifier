import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "shared" as UI
import "components"

// Development environments of any project folder: direnv state, the .envrc,
// flake inputs and devShells. Nothing here is specific to NixOS.
Item {
    id: devEnvTab

    required property color accentColor
    required property color textColor
    required property real fs
    required property var devEnvResult
    required property var devEnvProjects
    required property string activeViewMode
    property string systemFlakePath: ""
    property bool isProbingDevEnv: false

    readonly property var result: devEnvResult
    readonly property bool found: !!result && !result.isError

    signal devEnvRequested(string path)
    signal discoverRequested
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "devenv"
    onVisibleChanged: if (visible)
        discoverRequested()

    function inspect(path) {
        const target = (path !== undefined ? path : pathField.text).trim();
        if (target === "" || isProbingDevEnv)
            return;
        pathField.text = target;
        devEnvRequested(target);
    }
    function ago(epoch) {
        if (!epoch)
            return "—";
        const days = Math.floor((Date.now() / 1000 - epoch) / 86400);
        if (days < 1)
            return qsTr("today");
        if (days === 1)
            return qsTr("yesterday");
        if (days < 60)
            return qsTr("%1 days ago").arg(days);
        if (days < 730)
            return qsTr("%1 months ago").arg(Math.round(days / 30));
        return qsTr("%1 years ago").arg(Math.round(days / 365));
    }
    function staleTone(epoch) {
        const days = (Date.now() / 1000 - epoch) / 86400;
        return !epoch ? UI.Theme.muted : days > 180 ? UI.Theme.negative : days > 60 ? UI.Theme.changed : UI.Theme.positive;
    }
    function stateLabel(state) {
        switch (state) {
        case "allowed":
            return qsTr("Allowed");
        case "blocked":
            return qsTr("Blocked");
        case "denied":
            return qsTr("Denied");
        case "unknown":
            return qsTr("direnv missing");
        }
        return qsTr("Not set up");
    }
    function stateTone(state) {
        return state === "allowed" ? UI.Theme.positive : state === "blocked" || state === "unknown" ? UI.Theme.changed : state === "denied" ? UI.Theme.negative : UI.Theme.muted;
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                text: qsTr("See how a project's development environment is set up: direnv, Nix flakes, shell.nix and devenv. Works for any folder, on any distribution.")
                color: "#9bacc4"
                font.pixelSize: UI.Theme.fontPx(11, devEnvTab.fs)
                wrapMode: Text.Wrap
                lineHeight: 1.5
            }
            Text {
                Layout.bottomMargin: 7
                text: qsTr("Project folder")
                color: "#a3b2c9"
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                FieldInput {
                    id: pathField
                    objectName: "devEnvInput"
                    Layout.fillWidth: true
                    mono: true
                    placeholderText: "~/projects/my-app"
                    accent: devEnvTab.accentColor
                    textColor: devEnvTab.textColor
                    fs: devEnvTab.fs
                    onAccepted: devEnvTab.inspect()
                }
                UI.ActionButton {
                    objectName: "devEnvInspect"
                    implicitHeight: pathField.implicitHeight
                    text: devEnvTab.isProbingDevEnv ? qsTr("Inspecting…") : qsTr("Inspect")
                    glyph: Qt.resolvedUrl("assets/ic_search.svg")
                    primary: true
                    accent: devEnvTab.accentColor
                    font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                    enabled: pathField.text.trim() !== "" && !devEnvTab.isProbingDevEnv
                    onClicked: devEnvTab.inspect()
                }
            }

            // Folders direnv already knows, plus the system flake as a shortcut.
            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 20
                visible: projects.count > 0
                text: qsTr("Your projects")
                detail: qsTr("from direnv")
                fs: devEnvTab.fs
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 9
                spacing: 7
                visible: projects.count > 0
                Repeater {
                    id: projects
                    model: {
                        const list = devEnvTab.devEnvProjects.slice(0, 24);
                        if (devEnvTab.systemFlakePath !== "" && !list.some(p => p.dir === devEnvTab.systemFlakePath))
                            list.unshift({
                                dir: devEnvTab.systemFlakePath,
                                name: qsTr("System flake"),
                                state: ""
                            });
                        return list;
                    }
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: devEnvTab.found && devEnvTab.result.dir === modelData.dir
                        implicitWidth: chipText.implicitWidth + 22
                        implicitHeight: chipText.implicitHeight + 14
                        radius: 8
                        color: current ? UI.Theme.wash(devEnvTab.accentColor, .16) : chipArea.containsMouse ? "#0affffff" : "#05ffffff"
                        border.color: current ? devEnvTab.accentColor : "#10ffffff"
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.name
                            color: devEnvTab.textColor
                            font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devEnvTab.inspect(chip.modelData.dir)
                        }
                        ToolTip.visible: chipArea.containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: chip.modelData.dir
                    }
                }
            }

            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: !!devEnvTab.result && devEnvTab.result.isError
                glyph: "ic_warning"
                tone: UI.Theme.negative
                emphasis: true
                fs: devEnvTab.fs
                text: devEnvTab.result && devEnvTab.result.isError ? devEnvTab.result.value : ""
            }

            // ── Overview ─────────────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: devEnvTab.found
                text: devEnvTab.found ? devEnvTab.result.name : ""
                color: devEnvTab.textColor
                font.pixelSize: UI.Theme.fontPx(15, devEnvTab.fs)
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 3
                visible: devEnvTab.found && devEnvTab.result.description !== ""
                text: devEnvTab.found ? devEnvTab.result.description : ""
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                wrapMode: Text.Wrap
            }
            InfoRows {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: devEnvTab.found
                textColor: devEnvTab.textColor
                fs: devEnvTab.fs
                rows: {
                    if (!devEnvTab.found)
                        return [];
                    const r = devEnvTab.result;
                    const out = [
                        {
                            label: qsTr("direnv"),
                            value: devEnvTab.stateLabel(r.envrcState) + (r.direnvVersion ? "  ·  " + r.direnvVersion : ""),
                            tone: devEnvTab.stateTone(r.envrcState)
                        }
                    ];
                    if (r.envrcUses.length)
                        out.push({
                            label: qsTr("Provides"),
                            value: r.envrcUses.join(", ")
                        });
                    if (r.cacheTime)
                        out.push({
                            label: qsTr("Cached environment"),
                            value: devEnvTab.ago(r.cacheTime) + (r.cacheKb ? "  ·  " + UI.Theme.formatBytes(r.cacheKb * 1024) : "")
                        });
                    if (r.lockNewest)
                        out.push({
                            label: qsTr("Flake inputs"),
                            value: qsTr("%1, oldest locked %2").arg(r.inputs.length).arg(devEnvTab.ago(r.lockOldest)),
                            tone: devEnvTab.staleTone(r.lockOldest)
                        });
                    if (r.files.length)
                        out.push({
                            label: qsTr("Project files"),
                            value: r.files.join(", ")
                        });
                    return out;
                }
            }
            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: devEnvTab.found && devEnvTab.result.envrcState === "none" && devEnvTab.result.files.indexOf("flake.nix") >= 0
                glyph: "ic_info"
                tone: UI.Theme.changed
                emphasis: true
                fs: devEnvTab.fs
                text: qsTr("This project has a flake but no .envrc. Add `use flake` to .envrc and run `direnv allow` to load its shell automatically.")
            }
            CodeBlock {
                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: devEnvTab.found && (devEnvTab.result.envrcState === "blocked" || devEnvTab.result.envrcState === "denied")
                label: qsTr("Allow this environment")
                text: devEnvTab.found ? "direnv allow " + devEnvTab.result.dir : ""
                accent: devEnvTab.accentColor
                textColor: devEnvTab.textColor
                fs: devEnvTab.fs
                onCopyRequested: t => devEnvTab.copyToClipboard(t)
            }

            // ── devShells ────────────────────────────────────────────────────
            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: devEnvTab.found && devEnvTab.result.shells.length > 0
                text: qsTr("Dev shells")
                detail: devEnvTab.found ? String(devEnvTab.result.shells.length) : ""
                fs: devEnvTab.fs
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 9
                spacing: 7
                visible: devEnvTab.found && devEnvTab.result.shells.length > 0
                Repeater {
                    model: devEnvTab.found ? devEnvTab.result.shells : []
                    Tag {
                        required property string modelData
                        text: modelData
                        tone: devEnvTab.accentColor
                        fs: devEnvTab.fs
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: devEnvTab.found && devEnvTab.result.files.indexOf("flake.nix") >= 0 && !devEnvTab.result.shellsKnown
                text: qsTr("Dev shells could not be listed offline. Evaluate the flake once with `nix flake show`, or check that flake.nix is tracked by git.")
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                wrapMode: Text.Wrap
            }

            // ── Flake inputs ─────────────────────────────────────────────────
            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: devEnvTab.found && devEnvTab.result.inputs.length > 0
                text: qsTr("Flake inputs")
                detail: devEnvTab.found ? String(devEnvTab.result.inputs.length) : ""
                fs: devEnvTab.fs
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 9
                visible: devEnvTab.found && devEnvTab.result.inputs.length > 0
                implicitHeight: inputList.implicitHeight + 12
                radius: 9
                color: "#03ffffff"
                border.color: "#0effffff"
                ColumnLayout {
                    id: inputList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 0
                    Repeater {
                        model: devEnvTab.found ? devEnvTab.result.inputs : []
                        RowLayout {
                            id: inputRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.topMargin: 7
                            Layout.bottomMargin: 7
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: inputRow.modelData.name
                                    color: devEnvTab.textColor
                                    font.pixelSize: UI.Theme.fontPx(11, devEnvTab.fs)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: inputRow.modelData.follows !== "" ? qsTr("follows %1").arg(inputRow.modelData.follows) : [inputRow.modelData.source, inputRow.modelData.ref].filter(x => x).join(" · ")
                                    color: UI.Theme.muted
                                    font.family: UI.Theme.fixedWidthFont.family
                                    font.pixelSize: UI.Theme.fontPx(9, devEnvTab.fs)
                                    elide: Text.ElideMiddle
                                }
                            }
                            Text {
                                visible: inputRow.modelData.rev !== ""
                                text: inputRow.modelData.rev
                                color: UI.Theme.muted
                                font.family: UI.Theme.fixedWidthFont.family
                                font.pixelSize: UI.Theme.fontPx(9, devEnvTab.fs)
                            }
                            Text {
                                visible: inputRow.modelData.modified > 0
                                text: devEnvTab.ago(inputRow.modelData.modified)
                                color: devEnvTab.staleTone(inputRow.modelData.modified)
                                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                            }
                        }
                    }
                }
            }

            // ── .envrc ───────────────────────────────────────────────────────
            CodeBlock {
                Layout.fillWidth: true
                Layout.topMargin: 22
                Layout.bottomMargin: 6
                visible: devEnvTab.found && devEnvTab.result.envrc !== ""
                label: ".envrc"
                text: devEnvTab.found ? devEnvTab.result.envrc : ""
                accent: devEnvTab.accentColor
                textColor: devEnvTab.textColor
                fs: devEnvTab.fs
                maximumHeight: 190
                onCopyRequested: t => devEnvTab.copyToClipboard(t)
            }
        }
    }
}
