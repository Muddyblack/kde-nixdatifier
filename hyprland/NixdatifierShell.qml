import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../package/contents/ui" as App
import "../package/contents/ui/shared" as UI
import "../package/contents/ui/SettingsSchema.js" as Schema

ShellRoot {
    id: root
    property bool popupOpen: false
    property bool settingsOpen: false
    property bool configReady: false
    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/nixdatifier/hyprland.json"
    readonly property string statusPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nixdatifier-" + Quickshell.env("USER") + "/status.json"
    readonly property bool topEdge: cfg.popupPosition.indexOf("bottom") !== 0
    readonly property bool leftEdge: cfg.popupPosition.endsWith("left")
    readonly property bool rightEdge: cfg.popupPosition.endsWith("right")
    readonly property bool smokeTest: Quickshell.env("NIXDATIFIER_SMOKE_TEST") === "1"
    function copySettings(from, to) {
        for (const f of Schema.fields)
            to[f.key] = from[f.key];
        to.pillMode = from.pillMode;
        to.popupPosition = from.popupPosition;
    }
    function configure() {
        copySettings(cfg, draft);
        settingsOpen = true;
        popupOpen = true;
    }
    function applySettings() {
        settingsEditor.forceActiveFocus();
        copySettings(draft, cfg);
        settingsFile.writeAdapter();
    }
    FileView {
        id: settingsFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.configReady = true
        onLoadFailed: root.configReady = true
        onAdapterUpdated: if (root.configReady && !root.smokeTest)
            writeAdapter()
        JsonAdapter {
            id: cfg
            property string flakePath: ""
            property string configRepoPath: ""
            property int checkInterval: 3600
            property int maxGenerations: 10
            property string defaultView: "timeline"
            property bool enableHostDetect: true
            property string customCommands: "[{\"label\":\"update\",\"cmd\":\"nix flake update\"},{\"label\":\"upnix\",\"cmd\":\"upnix\"}]"
            property bool showCommandButtons: true
            property string commandTerminal: ""
            property bool usePkexec: true
            property bool enableLiveSwitch: true
            property bool confirmBeforeRollback: true
            property bool confirmBeforeDelete: true
            property bool showDeleteButton: true
            property bool showNotifications: true
            property bool autoRefreshOnOpen: true
            property bool showFlakeSection: true
            property string secretsPath: ""
            property string secretsSourcePath: ""
            property bool diffFilterEnabled: true
            property color timelineColor: "#71849b"
            property color accentColor: "#91bcff"
            property real fontScale: 1.0
            property bool showBg: true
            property string bgColor: "#f5131923"
            property real bgRadius: 14.0
            property bool useSystemTextColor: true
            property color customTextColor: "#ffffff"
            property bool enableGlow: true
            property string iconStyle: "colored"
            property string diffViewMode: "compact"
            property bool showPackageIcons: true
            property string compactStyle: "icon"
            property bool compactShowBadge: true
            property int popupWidth: 600
            property int popupHeight: 740
            property string gcCustomCommand: ""
            property bool enableMotion: true
            property string pillMode: "always"
            property string popupPosition: "top-right"
        }
    }
    App.Settings {
        id: draft
    }
    Component {
        id: processAdapter
        ProcessAdapter {}
    }
    App.Engine {
        id: core
        settings: cfg
        executor: processAdapter
        autoStart: false
        expanded: root.popupOpen && !root.settingsOpen
        onConfigureRequested: root.configure()
    }
    onConfigReadyChanged: if (configReady && !smokeTest) {
        core.autoStart = true;
        core.start();
    }
    Component.onCompleted: {
        UI.Theme.iconResolver = function (name) {
            return name ? Quickshell.iconPath(name, true) : "";
        };
        if (smokeTest) {
            root.popupOpen = true;
            testTimer.start();
        }
    }
    Timer {
        id: testTimer
        interval: 1200
        onTriggered: {
            console.log("NIXDATIFIER_HOST_LOADED");
            Qt.quit();
        }
    }
    FileView {
        id: statusFile
        path: root.smokeTest ? "" : root.statusPath
        atomicWrites: true
        printErrors: false
        onAdapterUpdated: if (!root.smokeTest)
            writeAdapter()
        JsonAdapter {
            property bool working: core.isSpinning
            property bool motion: cfg.enableMotion
            property string iconStyle: cfg.iconStyle
            property string accent: String(cfg.accentColor)
            property string summary: core.toolTipMainText + "\n" + core.toolTipSubText
            property int updates: cfg.compactShowBadge ? core.flakeUpdates.length : 0
        }
    }
    IpcHandler {
        target: "panel"
        function toggle(): void {
            root.popupOpen = !root.popupOpen;
        }
        function show(): void {
            root.popupOpen = true;
        }
        function hide(): void {
            root.popupOpen = false;
        }
        function refresh(): void {
            core.refreshGenerations();
            core.checkFlakeUpdates();
        }
        function configure(): void {
            root.configure();
        }
        function summary(): string {
            return core.toolTipSubText;
        }
        function quit(): void {
            Qt.quit();
        }
    }
    PanelWindow {
        id: pillWindow
        property bool revealed: false
        readonly property bool shown: cfg.pillMode === "always" || revealed || root.popupOpen
        visible: cfg.pillMode !== "tray"
        color: "transparent"
        exclusiveZone: 0
        aboveWindows: true
        implicitWidth: shown ? 106 : 72
        implicitHeight: shown ? 38 : 4
        anchors {
            top: root.topEdge
            bottom: !root.topEdge
            left: root.leftEdge
            right: root.rightEdge
        }
        margins {
            top: shown ? 4 : 0
            bottom: shown ? 4 : 0
            left: 8
            right: 8
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 17
            color: cfg.bgColor
            border.color: UI.Theme.line
            visible: pillWindow.shown
            App.CompactView {
                anchors.fill: parent
                anchors.margins: 3
                accentColor: core.accentColor
                textColor: core.textColor
                activeGenNum: core.activeGenNum
                flakeUpdates: core.flakeUpdates
                isBusy: core.isBusy
                isLoadingGens: core.isLoadingGens
                isSpinning: core.isSpinning
                enableMotion: cfg.enableMotion
                compactStyle: "pill"
                compactShowBadge: cfg.compactShowBadge
                iconStyle: cfg.iconStyle
                onToggleExpanded: root.popupOpen = !root.popupOpen
            }
        }
        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) {
                    pillWindow.revealed = true;
                    hidePill.stop();
                } else
                    hidePill.restart();
            }
        }
        Timer {
            id: hidePill
            interval: 400
            onTriggered: if (!hover.hovered)
                pillWindow.revealed = false
        }
        Timer {
            id: tipDelay
            interval: 500
            running: hover.hovered && pillWindow.shown && !root.popupOpen
        }
    }
    // Separate popup so the tooltip isn't clipped to the pill's tiny layer surface.
    PopupWindow {
        id: pillTip
        visible: pillWindow.visible && hover.hovered && !tipDelay.running && pillWindow.shown && !root.popupOpen && !root.smokeTest
        color: "transparent"
        anchor.window: pillWindow
        anchor.rect.x: 0
        anchor.rect.y: root.topEdge ? 0 : -6
        anchor.rect.width: pillWindow.width
        anchor.rect.height: pillWindow.height + 6
        anchor.edges: (root.topEdge ? Edges.Bottom : Edges.Top) | (root.leftEdge ? Edges.Left : root.rightEdge ? Edges.Right : 0)
        anchor.gravity: (root.topEdge ? Edges.Bottom : Edges.Top) | (root.leftEdge ? Edges.Right : root.rightEdge ? Edges.Left : 0)
        implicitWidth: tipBox.implicitWidth
        implicitHeight: tipBox.implicitHeight
        Rectangle {
            id: tipBox
            anchors.fill: parent
            implicitWidth: tipText.width + 20
            implicitHeight: tipText.implicitHeight + 14
            radius: 8
            color: cfg.bgColor
            border.color: UI.Theme.line
            Column {
                id: tipText
                x: 10
                y: 7
                width: Math.min(360, Math.max(tipMain.implicitWidth, tipSub.implicitWidth))
                spacing: 2
                Text {
                    id: tipMain
                    width: parent.width
                    text: core.toolTipMainText
                    color: core.textColor
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                Text {
                    id: tipSub
                    width: parent.width
                    visible: text !== ""
                    text: core.toolTipSubText
                    color: UI.Theme.muted
                    wrapMode: Text.Wrap
                }
            }
        }
    }
    PanelWindow {
        id: popup
        visible: root.popupOpen
        color: "transparent"
        focusable: true
        exclusiveZone: 0
        aboveWindows: true
        implicitWidth: Math.max(380, Math.min(cfg.popupWidth, screen ? screen.width - 24 : 600))
        implicitHeight: Math.max(420, Math.min(cfg.popupHeight, screen ? screen.height - 64 : 740))
        anchors {
            top: root.topEdge
            bottom: !root.topEdge
            left: root.leftEdge
            right: root.rightEdge
        }
        margins {
            top: 46
            bottom: 46
            left: 12
            right: 12
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                if (root.settingsOpen)
                    root.settingsOpen = false;
                else
                    root.popupOpen = false;
            }
            App.ApplicationView {
                anchors.fill: parent
                engine: core
                visible: !root.settingsOpen
            }
            Rectangle {
                anchors.fill: parent
                visible: root.settingsOpen
                color: UI.Theme.backgroundColor
                radius: 14
                border.color: UI.Theme.line
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14
                    Text {
                        text: qsTr("Nixdatifier settings")
                        color: UI.Theme.textColor
                        font.pixelSize: 20
                    }
                    App.SettingsEditor {
                        id: settingsEditor
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        settings: draft
                        hyprland: true
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        UI.ActionButton {
                            text: qsTr("Cancel")
                            onClicked: root.settingsOpen = false
                        }
                        UI.ActionButton {
                            text: qsTr("Apply")
                            onClicked: root.applySettings()
                        }
                        UI.ActionButton {
                            text: qsTr("OK")
                            primary: true
                            onClicked: {
                                root.applySettings();
                                root.settingsOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
    HyprlandFocusGrab {
        active: root.popupOpen && !core.pinned && !root.smokeTest
        windows: [popup]
        onCleared: root.popupOpen = false
    }
}
