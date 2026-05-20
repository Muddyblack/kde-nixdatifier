import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Size hints ────────────────────────────────────────────────────────────
    Layout.minimumWidth:   300
    Layout.preferredWidth: 440
    Layout.minimumHeight:  320
    Layout.preferredHeight: 560

    Plasmoid.backgroundHints: plasmoid.configuration.showBg ? Plasmoid.NoBackground : Plasmoid.DefaultBackground

    // ── Theme / Config aliases ─────────────────────────────────────────────
    readonly property color accentColor:    Kirigami.Theme.highlightColor
    readonly property color timelineColor:  plasmoid.configuration.timelineColor || "#9b5de5"
    readonly property color textColor:      plasmoid.configuration.useSystemTextColor
                                                ? Kirigami.Theme.textColor
                                                : (plasmoid.configuration.customTextColor || "#ffffff")
    readonly property string flakePath:     plasmoid.configuration.flakePath || ""
    readonly property real   fs:            plasmoid.configuration.fontScale || 1.0
    readonly property string updateCmd:     plasmoid.configuration.updateCommand || "update"
    readonly property string redeployCmd:   plasmoid.configuration.redeployCommand || "upnix"
    readonly property string terminalApp:   plasmoid.configuration.commandTerminal || "konsole"

    // ── State ────────────────────────────────────────────────────────────────
    property var    generations:      []
    property string activeStorePath:  ""
    property string bootedStorePath:  ""
    property int    activeGenNum:     -1
    property int    bootedGenNum:     -1
    property int    selectedGenNum:   -1
    property bool   isLoadingGens:    false
    property bool   isLoadingDetails: false
    property bool   isBusy:           false        // rollback / delete in progress
    property var    detailsCache:     ({})
    property string diffFilter:       ""
    property string diffMode:         "booted" // "booted" | "prev"

    property var    flakeUpdates:        []
    property bool   isCheckingFlake:     false
    property string lastFlakeCheckTime:  ""

    // pending rollback / delete action for confirmation dialog
    property int    pendingGenNum:  -1
    property string pendingAction:  ""   // "rollback" | "delete"

    // ── Toast notification queue ──────────────────────────────────────────────
    property var toasts: []

    function pushToast(message, isError) {
        var arr = root.toasts.slice()
        arr.push({ msg: message, err: isError || false, id: Date.now() })
        root.toasts = arr
        toastDismissTimer.restart()
    }

    Timer {
        id: toastDismissTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (root.toasts.length === 0) return
            var arr = root.toasts.slice()
            // Drop only the first non-error toast; errors stay until manually closed
            var idx = -1
            for (var i = 0; i < arr.length; i++) {
                if (!arr[i].err) { idx = i; break }
            }
            if (idx === -1) return
            arr.splice(idx, 1)
            root.toasts = arr
            // Keep ticking if there are more non-error toasts to clear
            for (var j = 0; j < arr.length; j++) {
                if (!arr[j].err) { restart(); return }
            }
        }
    }

    TextEdit {
        id: clipboardHelper
        visible: false
    }

    function copyToClipboard(text) {
        clipboardHelper.text = text
        clipboardHelper.selectAll()
        clipboardHelper.copy()
        root.pushToast(i18n("Copied error to clipboard"), false)
    }

    // ── DataSources ──────────────────────────────────────────────────────────
    P5Support.DataSource {
        id: gensSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            root.isLoadingGens = false
            gensSource.disconnectSource(sourceName)
            // We always exit 0, so treat empty stdout as "not found"
            const out = (data["stdout"] || "").trim()
            if (!out) {
                root.pushToast(i18n("No generations found — is /nix/var/nix/profiles/ accessible?"), true)
                return
            }
            root.parseGenerations(out)
        }
    }

    P5Support.DataSource {
        id: detailsSource
        engine: "executable"
        connectedSources: []
        property int queryGenNum: -1
        onNewData: function(sourceName, data) {
            root.isLoadingDetails = false
            detailsSource.disconnectSource(sourceName)
            // We always exit 0; any real failure shows up as empty/garbled output
            root.parseDetails(queryGenNum, data["stdout"] || "")
        }
    }

    P5Support.DataSource {
        id: actionSource
        engine: "executable"
        connectedSources: []
        property string actionType: ""
        property int    actionGenNum: -1
        onNewData: function(sourceName, data) {
            root.isBusy = false
            actionSource.disconnectSource(sourceName)
            if (data["exitCode"] !== 0) {
                var errMsg = (data["stderr"] || data["stdout"] || "").trim()
                if (actionType === "rollback") {
                    root.pushToast(i18n("Rollback failed: ") + errMsg, true)
                } else {
                    root.pushToast(i18n("Delete failed: ") + errMsg, true)
                }
                return
            }
            if (actionType === "rollback") {
                root.pushToast(i18n("Generation %1 marked for next boot. Reboot to activate.").arg(actionGenNum), false)
            } else {
                root.pushToast(i18n("Generation %1 deleted.").arg(actionGenNum), false)
                // Deselect if we deleted the selected one
                if (root.selectedGenNum === actionGenNum) root.selectedGenNum = -1
            }
            root.refreshGenerations()
        }
    }

    // ── Command runner (update / redeploy) ─────────────────────────────────
    P5Support.DataSource {
        id: commandSource
        engine: "executable"
        connectedSources: []
        property string commandLabel: ""
        onNewData: function(sourceName, data) {
            commandSource.disconnectSource(sourceName)
            // terminal launched in background – nothing to parse
        }
    }

    function runCustomCommand(cmd, label) {
        // Launch in a terminal window. We try to stay compatible with
        // konsole, kitty, alacritty, foot, xterm, etc.
        // Strategy: <terminal> --hold -e bash -c '<cmd>'
        // For konsole we need  -e  without --hold (konsole keeps window open with -e)
        const workDir = (root.flakePath !== "") ? root.flakePath : "~"
        const term = root.terminalApp
        let shellCmd
        if (term === "konsole" || term === "konsole-nkde") {
            shellCmd = term + " --workdir " + workDir + " -e bash -c '" + cmd + "; echo; echo \"--- done ---\"; read -n1'"
        } else if (term === "kitty" || term === "foot" || term === "wezterm") {
            shellCmd = term + " bash -c 'cd " + workDir + " && " + cmd + "; echo; echo \"--- done ---\"; read -n1'"
        } else {
            shellCmd = term + " --hold -e bash -c 'cd " + workDir + " && " + cmd + "'"
        }
        commandSource.commandLabel = label
        commandSource.connectSource("sh -c \"" + shellCmd.replace(/"/g, '\\"') + " &\"")
        root.pushToast(i18n("Launching: %1").arg(label), false)
    }

    // Stage 1: read local flake.lock
    P5Support.DataSource {
        id: flakeLockSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            flakeLockSource.disconnectSource(sourceName)
            const text = (data["stdout"] || "").trim()
            if (!text) {
                root.isCheckingFlake = false
                root.pushToast(i18n("Could not read flake.lock at %1").arg(root.flakePath), true)
                return
            }
            root.startRemoteProbe(text)
        }
    }

    // Stage 2: probe remote refs via git ls-remote
    P5Support.DataSource {
        id: flakeRemoteSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            root.isCheckingFlake = false
            flakeRemoteSource.disconnectSource(sourceName)
            root.parseRemoteProbe(data["stdout"] || "")
        }
    }

    property var _pendingProbes: []

    // ── Operations ───────────────────────────────────────────────────────────
    function refreshGenerations() {
        if (root.isLoadingGens) return
        root.isLoadingGens = true
        // find avoids glob-expansion issues; semicolons instead of && so a missing
        // active symlink doesn't abort the list; explicit exit 0 so DataSource
        // never sees a non-zero exitCode from a missing-but-harmless path.
        const cmd = "sh -c \"" +
                    "readlink -f /nix/var/nix/profiles/system 2>/dev/null; " +
                    "readlink -f /run/booted-system 2>/dev/null; " +
                    "find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' -type l " +
                    "  -exec stat --format='%y %N' {} + 2>/dev/null; exit 0\""
        gensSource.connectSource(cmd)
    }

    function getPreviousGen(genNum) {
        for (let i = 0; i < root.generations.length; i++) {
            if (root.generations[i].number === genNum) {
                if (i + 1 < root.generations.length) {
                    return root.generations[i + 1].number
                }
                break
            }
        }
        return null
    }

    function loadGenDetails(genNum) {
        if (root.detailsCache[genNum] !== undefined) {
            root.selectedGenNum = genNum
            return
        }
        if (root.isLoadingDetails) return
        root.isLoadingDetails = true
        detailsSource.queryGenNum = genNum
        const link = "/nix/var/nix/profiles/system-" + genNum + "-link"

        // Find if this generation is active or booted
        let isActive = false
        let isBooted = false
        for (let i = 0; i < root.generations.length; i++) {
            if (root.generations[i].number === genNum) {
                isActive = root.generations[i].active
                isBooted = root.generations[i].booted
                break
            }
        }

        let baseProfilePath = ""
        if (isBooted) {
            // Booted generation: always compare vs previous
            const prev = root.getPreviousGen(genNum)
            if (prev !== null) {
                baseProfilePath = "/nix/var/nix/profiles/system-" + prev + "-link"
            } else {
                baseProfilePath = link
            }
        } else {
            // Non-booted generation
            if (root.diffMode === "booted") {
                const bootedPath = root.bootedStorePath !== "" ? root.bootedStorePath : root.activeStorePath
                baseProfilePath = bootedPath !== "" ? bootedPath : link
            } else {
                const prev = root.getPreviousGen(genNum)
                if (prev !== null) {
                    baseProfilePath = "/nix/var/nix/profiles/system-" + prev + "-link"
                } else {
                    baseProfilePath = link
                }
            }
        }

        // Semicolons + exit 0 so the command never fails even if diff-closures errors
        const cmd = "sh -c \"cat " + link + "/nixos-version 2>/dev/null; echo; " +
                    "readlink " + link + "/kernel 2>/dev/null; echo; " +
                    "nix --extra-experimental-features 'nix-command' store diff-closures " + baseProfilePath + " " + link + " 2>/dev/null; exit 0\""
        detailsSource.connectSource(cmd)
    }

    function checkFlakeUpdates() {
        if (root.isCheckingFlake || root.flakePath === "") return
        root.isCheckingFlake = true
        flakeLockSource.connectSource("cat " + root.flakePath + "/flake.lock 2>/dev/null")
    }

    function startRemoteProbe(lockText) {
        let lock
        try {
            lock = JSON.parse(lockText)
        } catch(e) {
            root.isCheckingFlake = false
            root.pushToast(i18n("Failed to parse flake.lock: %1").arg(e), true)
            return
        }
        const nodes = lock.nodes || {}
        const rootInputs = (nodes.root && nodes.root.inputs) ? nodes.root.inputs : {}
        const probes = []
        for (const key in rootInputs) {
            const refKey = rootInputs[key]
            if (typeof refKey !== "string") continue
            const node = nodes[refKey]
            if (!node || !node.locked || !node.original) continue
            const orig = node.original
            const locked = node.locked
            let url = ""
            if (orig.type === "github") {
                url = "https://github.com/" + orig.owner + "/" + orig.repo + ".git"
            } else if (orig.type === "gitlab") {
                url = "https://gitlab.com/" + orig.owner + "/" + orig.repo + ".git"
            } else if (orig.type === "git") {
                url = orig.url || ""
                if (url.indexOf("git+") === 0) url = url.substring(4)
            } else {
                continue
            }
            if (!url) continue
            probes.push({
                name: key,
                url: url,
                ref: orig.ref || "",
                currentRev: locked.rev || "",
                currentDate: locked.lastModified || 0
            })
        }
        if (probes.length === 0) {
            root.isCheckingFlake = false
            root.flakeUpdates = []
            root.lastFlakeCheckTime = new Date().toLocaleTimeString()
            return
        }
        root._pendingProbes = probes

        let script = ""
        for (let i = 0; i < probes.length; i++) {
            const p = probes[i]
            const refs = p.ref
                ? "'refs/heads/" + p.ref + "' 'refs/tags/" + p.ref + "' '" + p.ref + "'"
                : "HEAD"
            // Each probe prints: "name|<remote-sha>" then newline
            script += "printf '" + p.name + "|'; "
            script += "git ls-remote '" + p.url + "' " + refs + " 2>/dev/null | head -1 | cut -f1; "
        }
        script += "exit 0"
        flakeRemoteSource.connectSource("sh -c \"" + script.replace(/"/g, '\\"') + "\"")
    }

    function parseRemoteProbe(text) {
        const lines = text.split("\n")
        const byName = {}
        for (let i = 0; i < root._pendingProbes.length; i++) {
            byName[root._pendingProbes[i].name] = root._pendingProbes[i]
        }
        const updates = []
        const unreachable = []
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const sep = line.indexOf("|")
            if (sep < 0) continue
            const name = line.substring(0, sep)
            const remoteRev = line.substring(sep + 1).trim()
            const probe = byName[name]
            if (!probe) continue
            if (!remoteRev) {
                unreachable.push(name)
                continue
            }
            if (probe.currentRev && remoteRev !== probe.currentRev) {
                const repoUrl = probe.url.replace(/\.git$/, "")
                updates.push({
                    input:   name,
                    oldRev:  probe.currentRev.substring(0, 7),
                    newRev:  remoteRev.substring(0, 7),
                    oldDate: probe.currentDate ? new Date(probe.currentDate * 1000).toLocaleDateString() : "",
                    newDate: i18n("latest"),
                    url:     repoUrl
                })
            }
        }
        root.flakeUpdates = updates
        root.lastFlakeCheckTime = new Date().toLocaleTimeString()

        if (unreachable.length > 0) {
            root.pushToast(i18n("Could not reach: %1").arg(unreachable.join(", ")), true)
        }

        if (updates.length > 0 && plasmoid.configuration.showNotifications) {
            const p = Qt.createQmlObject(
                'import org.kde.plasma.plasma5support as P5Support; P5Support.DataSource { engine: "executable" }',
                root)
            p.connectSource("notify-send -i system-software-update 'NixOS Flake Updates' '" + updates.length + " flake input(s) have updates available'")
        }
    }

    function requestAction(genNum, action) {
        if (plasmoid.configuration.confirmBeforeRollback) {
            root.pendingGenNum = genNum
            root.pendingAction = action
            confirmDialog.open()
        } else {
            executeAction(genNum, action)
        }
    }

    function executeAction(genNum, action) {
        if (root.isBusy) return
        root.isBusy = true
        actionSource.actionType = action
        actionSource.actionGenNum = genNum
        const prefix = plasmoid.configuration.usePkexec ? "pkexec " : ""
        var cmd
        if (action === "rollback") {
            // Switch the system profile to the chosen generation, then re-run
            // switch-to-configuration boot so the bootloader entry is updated.
            // We use the profile symlink's own switch-to-configuration so it
            // matches that generation's NixOS version.
            cmd = "sh -c \"" + prefix + "nix-env --profile /nix/var/nix/profiles/system --switch-generation " + genNum +
                  " && " + prefix + "/nix/var/nix/profiles/system/bin/switch-to-configuration boot 2>&1\""
        } else {
            cmd = "sh -c \"" + prefix + "nix-env --profile /nix/var/nix/profiles/system --delete-generations " + genNum + " 2>&1\""
        }
        actionSource.connectSource(cmd)
    }

    // ── Parsers ───────────────────────────────────────────────────────────────
    function parseGenerations(text) {
        const lines = text.trim().split("\n")
        if (lines.length < 1) return

        // First line is readlink output (active store path).
        // Second line is readlink output for booted system.
        let activePath = ""
        let bootedPath = ""
        let startIdx   = 0
        if (lines[0] && (lines[0].startsWith("/nix/store/") || lines[0].startsWith("/nix/var/"))) {
            activePath = lines[0].trim()
            startIdx   = 1
            if (lines[1] && (lines[1].startsWith("/nix/store/") || lines[1].startsWith("/nix/var/"))) {
                bootedPath = lines[1].trim()
                startIdx   = 2
            }
        }
        root.activeStorePath = activePath
        root.bootedStorePath = bootedPath

        const list = []
        let activeNum = -1
        let bootedNum = -1

        for (let i = startIdx; i < lines.length; i++) {
            const line = lines[i]
            // stat %y %N: "2026-05-20 00:42:13.325 +0200 '/nix/.../system-398-link' -> '/nix/store/...'"
            const match = line.match(/^([\d-]+ [\d:]+)\.\d+ [+-]\d+ '([^']*system-(\d+)-link)' -> '([^']+)'/)
            if (match) {
                const time      = match[1]
                const genNum    = parseInt(match[3])
                const storePath = match[4]
                const isActive  = activePath !== "" && storePath === activePath
                const isBooted  = bootedPath !== "" && storePath === bootedPath
                if (isActive) activeNum = genNum
                if (isBooted) bootedNum = genNum
                list.push({ number: genNum, timestamp: time, storePath: storePath, active: isActive, booted: isBooted })
            }
        }

        // If nothing matched active yet, mark highest gen as active fallback
        if (activeNum === -1 && list.length > 0) {
            list.sort((a, b) => b.number - a.number)
            activeNum = list[0].number
            for (let i = 0; i < list.length; i++) {
                if (list[i].number === activeNum) {
                    list[i].active = true
                    break
                }
            }
        } else {
            list.sort((a, b) => b.number - a.number)
        }

        // Keep only the highest generation matching the booted store path
        let maxBootedGen = -1
        for (let i = 0; i < list.length; i++) {
            if (list[i].booted && list[i].number > maxBootedGen) {
                maxBootedGen = list[i].number
            }
        }
        if (maxBootedGen !== -1) {
            bootedNum = maxBootedGen
            for (let i = 0; i < list.length; i++) {
                list[i].booted = (list[i].number === bootedNum)
            }
        } else {
            bootedNum = activeNum
            for (let i = 0; i < list.length; i++) {
                list[i].booted = (list[i].number === bootedNum)
            }
        }

        const maxG = Math.max(3, plasmoid.configuration.maxGenerations || 10)
        if (list.length > maxG) list.splice(maxG)

        root.generations = list
        root.activeGenNum = activeNum
        root.bootedGenNum = bootedNum
    }

    function parseDetails(genNum, text) {
        const lines = text.split("\n")
        if (lines.length < 1) return
        const nixosVer   = lines[0].trim()
        const kernelPath = lines[2] ? lines[2].trim() : ""
        const kMatch     = kernelPath.match(/linux-([^\/\-]+(?:-[^\/]+)?)/)
        const kernelVer  = kMatch ? kMatch[1] : (kernelPath || "—")

        const diffList = []
        for (let i = 4; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line) continue
            const match = line.match(/^([^:]+):\s+(\S+)\s+(?:→|->)\s+([^\s,]+)(?:,\s+(.+))?/)
            if (match) {
                const name = match[1].trim()
                const oldV = match[2]
                const newV = match[3]
                const size = match[4] || ""
                let type = "upgrade"
                if (oldV === "∅" || oldV === "null") type = "added"
                else if (newV === "∅" || newV === "null") type = "removed"
                diffList.push({ name, oldVersion: oldV, newVersion: newV, size, type })
            } else {
                diffList.push({ name: line, oldVersion: "", newVersion: "", size: "", type: "info" })
            }
        }

        const cache = Object.assign({}, root.detailsCache)
        cache[genNum] = { nixosVer, kernelVer, diff: diffList }
        root.detailsCache = cache
        root.selectedGenNum = genNum
    }

    // ── Init & timers ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        refreshGenerations()
        if (root.flakePath !== "") checkFlakeUpdates()
    }

    onExpandedChanged: {
        if (expanded && plasmoid.configuration.autoRefreshOnOpen) {
            refreshGenerations()
        }
    }

    Timer {
        interval: Math.max(60, plasmoid.configuration.checkInterval || 3600) * 1000
        running: root.flakePath !== ""
        repeat: true
        onTriggered: checkFlakeUpdates()
    }

    // ── Confirmation Dialog ───────────────────────────────────────────────────
    Dialog {
        id: confirmDialog
        title: root.pendingAction === "rollback"
            ? i18n("Switch Generation")
            : i18n("Delete Generation")
        modal: true
        anchors.centerIn: parent
        width: Math.min(360, parent.width - 32)

        background: Rectangle {
            radius: 10
            color:  plasmoid.configuration.showBg
                        ? (plasmoid.configuration.bgColor || "#d90d0f1a")
                        : Kirigami.Theme.backgroundColor
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12
            anchors.margins: 4

            Kirigami.Icon {
                source: root.pendingAction === "rollback" ? "system-reboot" : "edit-delete"
                implicitWidth: 36; implicitHeight: 36
                color: root.pendingAction === "delete" ? "#ff5555" : root.accentColor
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: root.textColor
                font.pixelSize: Math.round(11 * root.fs)
                text: root.pendingAction === "rollback"
                    ? i18n("Boot into generation %1 on next reboot?\n\nThis switches the system profile and updates the bootloader. Your current session is unchanged — reboot to activate.%2")
                        .arg(root.pendingGenNum)
                        .arg(plasmoid.configuration.usePkexec ? i18n("\n\nA password prompt will appear.") : "")
                    : i18n("Permanently delete generation %1?\n\nThis cannot be undone.%2")
                        .arg(root.pendingGenNum)
                        .arg(plasmoid.configuration.usePkexec ? i18n("\n\nA password prompt will appear.") : "")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    Layout.fillWidth: true
                    text: i18n("Cancel")
                    onClicked: confirmDialog.close()
                    background: Rectangle {
                        radius: 4
                        color: parent.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                        border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text; color: root.textColor
                        font.pixelSize: Math.round(10 * root.fs)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: root.pendingAction === "rollback" ? i18n("Switch") : i18n("Delete")
                    onClicked: {
                        confirmDialog.close()
                        root.executeAction(root.pendingGenNum, root.pendingAction)
                    }
                    background: Rectangle {
                        radius: 4
                        color: root.pendingAction === "delete"
                            ? (parent.hovered ? Qt.rgba(1,0.2,0.2,0.35) : Qt.rgba(1,0.2,0.2,0.2))
                            : (parent.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                                              : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2))
                        border.color: root.pendingAction === "delete" ? "#ff5555" : root.accentColor
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text; color: root.textColor
                        font.pixelSize: Math.round(10 * root.fs); font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // ── Compact panel icon ────────────────────────────────────────────────────
    compactRepresentation: Item {
        id: compactRoot
        implicitWidth:  Kirigami.Units.gridUnit * 2.2
        implicitHeight: Kirigami.Units.gridUnit * 2.2

        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight

        readonly property string style: plasmoid.configuration.compactStyle || "icon"

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            z: 10
            onClicked: root.expanded = !root.expanded
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 5
            color: compactMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Icon-only or icon+label
        Kirigami.Icon {
            id: compactIcon
            visible: compactRoot.style !== "number"
            source: Qt.resolvedUrl("nixos-logo.svg")
            color: root.flakeUpdates.length > 0 ? "#cc88ff" : root.accentColor
            anchors.centerIn: parent
            implicitWidth:  compactRoot.style === "both" ? parent.width * 0.55 : parent.width - 10
            implicitHeight: implicitWidth
            anchors.verticalCenterOffset: compactRoot.style === "both" ? -4 : 0
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Generation number label (for "number" and "both" styles)
        Text {
            visible: compactRoot.style !== "icon" && root.activeGenNum > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: compactRoot.style === "both" ? 3 : 0
            anchors.verticalCenter: compactRoot.style === "number" ? parent.verticalCenter : undefined
            text: root.activeGenNum > 0 ? root.activeGenNum : "—"
            color: root.textColor
            font.pixelSize: compactRoot.style === "both" ? 8 : 11
            font.bold: true
        }

        // Update badge
        Rectangle {
            visible: plasmoid.configuration.compactShowBadge && root.flakeUpdates.length > 0
            anchors.top: parent.top;  anchors.right: parent.right
            anchors.topMargin: 3;     anchors.rightMargin: 3
            width: 14; height: 14; radius: 7
            color: "#cc88ff"
            border.color: Kirigami.Theme.backgroundColor; border.width: 1.5

            Text {
                anchors.centerIn: parent
                text: root.flakeUpdates.length
                color: "#ffffff"; font.pixelSize: 8; font.bold: true
            }
        }

        // Busy spinner overlay – rotating NixOS logo
        Kirigami.Icon {
            id: compactSpinner
            anchors.centerIn: parent
            visible: root.isBusy || root.isLoadingGens
            source: Qt.resolvedUrl("nixos-logo.svg")
            color: root.accentColor
            width: parent.width - 6; height: parent.height - 6
            RotationAnimation on rotation {
                running: compactSpinner.visible
                from: 0; to: 360
                duration: 1400
                loops: Animation.Infinite
            }
        }
    }

    // ── Full representation ───────────────────────────────────────────────────
    fullRepresentation: Item {
        id: container

        // Glass card background
        Rectangle {
            anchors.fill: parent
            radius: plasmoid.configuration.bgRadius || 12
            visible: plasmoid.configuration.showBg
            color: plasmoid.configuration.bgColor || "#d90d0f1a"
            border.color: Qt.rgba(1,1,1,0.10); border.width: 1

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 1
                height: 1; radius: 0.5
                color: Qt.rgba(1,1,1,0.18)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: plasmoid.configuration.showBg ? 12 : 4
            spacing: 8

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Kirigami.Icon {
                    source: Qt.resolvedUrl("nixos-logo.svg")
                    implicitWidth: 22; implicitHeight: 22
                    color: root.accentColor
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: i18n("NixOS Generations")
                        color: root.textColor
                        font.pixelSize: Math.round(13 * root.fs); font.bold: true
                    }
                    Text {
                        visible: plasmoid.configuration.showFlakeSection && root.flakePath !== ""
                        text: root.isCheckingFlake
                            ? i18n("Checking flake updates…")
                            : (root.flakeUpdates.length > 0
                                ? (root.flakeUpdates.length === 1
                                    ? i18n("1 flake update available")
                                    : i18n("%1 flake updates available").arg(root.flakeUpdates.length))
                                : (root.lastFlakeCheckTime
                                    ? i18n("Flake up-to-date · %1").arg(root.lastFlakeCheckTime)
                                    : i18n("Flake up-to-date")))
                        color: root.flakeUpdates.length > 0 ? "#cc88ff" : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.5)
                        font.pixelSize: Math.round(9 * root.fs)
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                // Custom command buttons
                RowLayout {
                    visible: plasmoid.configuration.showCommandButtons
                    spacing: 4

                    // Update command button
                    Rectangle {
                        visible: root.updateCmd !== ""
                        radius: 5
                        width: updateCmdLabel.implicitWidth + 14
                        height: 24
                        color: updateCmdArea.containsMouse
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                            : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Kirigami.Icon {
                                source: "system-software-update"
                                implicitWidth: 12; implicitHeight: 12
                                color: root.accentColor
                            }
                            Text {
                                id: updateCmdLabel
                                text: root.updateCmd
                                color: root.accentColor
                                font.pixelSize: Math.round(9 * root.fs); font.bold: true
                            }
                        }

                        MouseArea {
                            id: updateCmdArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runCustomCommand(root.updateCmd, root.updateCmd)
                        }

                        ToolTip.text: i18n("Run: %1").arg(root.updateCmd)
                        ToolTip.visible: updateCmdArea.containsMouse
                        ToolTip.delay: 600
                    }

                    // Redeploy command button
                    Rectangle {
                        visible: root.redeployCmd !== ""
                        radius: 5
                        width: redeployCmdLabel.implicitWidth + 14
                        height: 24
                        color: redeployCmdArea.containsMouse
                            ? Qt.rgba(0.5, 0.85, 0.3, 0.25)
                            : Qt.rgba(0.5, 0.85, 0.3, 0.12)
                        border.color: Qt.rgba(0.5, 0.85, 0.3, 0.55)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Kirigami.Icon {
                                source: "run-build"
                                implicitWidth: 12; implicitHeight: 12
                                color: "#88dd55"
                            }
                            Text {
                                id: redeployCmdLabel
                                text: root.redeployCmd
                                color: "#88dd55"
                                font.pixelSize: Math.round(9 * root.fs); font.bold: true
                            }
                        }

                        MouseArea {
                            id: redeployCmdArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runCustomCommand(root.redeployCmd, root.redeployCmd)
                        }

                        ToolTip.text: i18n("Run: %1").arg(root.redeployCmd)
                        ToolTip.visible: redeployCmdArea.containsMouse
                        ToolTip.delay: 600
                    }
                }

                // Refresh button
                ToolButton {
                    icon.name: root.isLoadingGens ? "process-working" : "view-refresh"
                    ToolTip.text: i18n("Refresh generations list")
                    ToolTip.visible: hovered
                    ToolTip.delay: 600
                    enabled: !root.isLoadingGens
                    opacity: enabled ? 1.0 : 0.4
                    implicitWidth: 28; implicitHeight: 28
                    onClicked: root.refreshGenerations()
                }

                // Check flake updates button
                ToolButton {
                    visible: plasmoid.configuration.showFlakeSection && root.flakePath !== ""
                    icon.name: "network-connect"
                    ToolTip.text: i18n("Check flake lock for updates")
                    ToolTip.visible: hovered
                    ToolTip.delay: 600
                    enabled: !root.isCheckingFlake
                    opacity: enabled ? 1.0 : 0.4
                    implicitWidth: 28; implicitHeight: 28
                    onClicked: root.checkFlakeUpdates()
                }
            }

            // ── Toast area ────────────────────────────────────────────────────
            Repeater {
                model: root.toasts
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: toastLayout.implicitHeight + 12
                    radius: 5
                    color: modelData.err ? Qt.rgba(1,0.2,0.2,0.15) : Qt.rgba(0.2,0.9,0.2,0.12)
                    border.color: modelData.err ? "#ff5555" : "#55cc55"
                    border.width: 1
                    clip: true

                    RowLayout {
                        id: toastLayout
                        anchors.fill: parent; anchors.margins: 6
                        spacing: 6
                        Kirigami.Icon {
                            source: modelData.err ? "dialog-error" : "dialog-ok"
                            implicitWidth: 14; implicitHeight: 14
                            color: modelData.err ? "#ff5555" : "#55cc55"
                            Layout.alignment: Qt.AlignTop
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.msg
                            color: root.textColor
                            font.pixelSize: Math.round(9 * root.fs)
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                        }
                        ToolButton {
                            visible: modelData.err
                            icon.name: "edit-copy"
                            implicitWidth: 18; implicitHeight: 18
                            Layout.alignment: Qt.AlignTop
                            ToolTip.text: i18n("Copy error message")
                            ToolTip.visible: hovered
                            ToolTip.delay: 600
                            onClicked: root.copyToClipboard(modelData.msg)
                        }
                        ToolButton {
                            icon.name: "window-close"
                            implicitWidth: 18; implicitHeight: 18
                            Layout.alignment: Qt.AlignTop
                            onClicked: {
                                var arr = root.toasts.slice()
                                arr.splice(index, 1)
                                root.toasts = arr
                            }
                        }
                    }
                }
            }

            // ── Busy indicator bar ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: root.isBusy ? 28 : 0
                clip: true
                radius: 5
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                border.width: 1
                Behavior on height { NumberAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent; anchors.margins: 6
                    spacing: 6
                    Kirigami.Icon {
                        id: busyBarSpinner
                        source: Qt.resolvedUrl("nixos-logo.svg")
                        color: root.accentColor
                        visible: root.isBusy
                        implicitWidth: 18; implicitHeight: 18
                        RotationAnimation on rotation {
                            running: busyBarSpinner.visible
                            from: 0; to: 360
                            duration: 1400
                            loops: Animation.Infinite
                        }
                    }
                    Text {
                        text: actionSource.actionType === "delete"
                            ? i18n("Deleting generation %1…").arg(actionSource.actionGenNum)
                            : i18n("Switching to generation %1…").arg(actionSource.actionGenNum)
                        color: root.textColor; font.pixelSize: Math.round(9 * root.fs)
                    }
                }
            }

            // ── Flake updates bar ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: (plasmoid.configuration.showFlakeSection && root.flakeUpdates.length > 0) ? 30 : 0
                clip: true; radius: 5
                color: Qt.rgba(0.7,0.4,1,0.12)
                border.color: Qt.rgba(0.7,0.4,1,0.3); border.width: 1
                Behavior on height { NumberAnimation { duration: 250 } }
                visible: height > 0

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 6
                    Kirigami.Icon { source: "update-none"; implicitWidth: 14; implicitHeight: 14; color: "#cc88ff" }
                    Text {
                        Layout.fillWidth: true
                        text: root.flakeUpdates.length === 1
                            ? i18n("1 flake input has available updates")
                            : i18n("%1 flake inputs have available updates").arg(root.flakeUpdates.length)
                        color: root.textColor; font.pixelSize: Math.round(9 * root.fs); font.bold: true
                    }
                    Button {
                        text: i18n("Details")
                        flat: true
                        implicitHeight: 22
                        font.pixelSize: Math.round(9 * root.fs)
                        onClicked: flakePopup.open()
                    }
                }
            }

            // ── Generations list ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: genListView
                    anchors.fill: parent
                    model: root.generations
                    clip: true
                    spacing: 0
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Item {
                        id: genDelegate
                        width: genListView.width
                        height: isExpanded ? headerH + detailsH + 8 : headerH
                        readonly property bool isExpanded: modelData.number === root.selectedGenNum
                        readonly property int  headerH: 44
                        readonly property int  detailsH: 280

                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

                        // Timeline track
                        Rectangle {
                            anchors.left: parent.left; anchors.leftMargin: 18
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: 2
                            color: (modelData.booted || modelData.active)
                                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)
                                : Qt.rgba(root.timelineColor.r, root.timelineColor.g, root.timelineColor.b, 0.2)
                        }

                        // Node dot
                        Rectangle {
                            id: nodeDot
                            anchors.left: parent.left; anchors.leftMargin: 13
                            anchors.top: parent.top; anchors.topMargin: 14
                            width: 12; height: 12; radius: 6
                            color: (modelData.booted || modelData.active) ? root.accentColor : root.timelineColor
                            border.color: Qt.rgba(color.r, color.g, color.b, 0.4)
                            border.width: 3

                            // Pulse ring for booted
                            Rectangle {
                                anchors.centerIn: parent
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.color: nodeDot.color; border.width: 1
                                visible: modelData.booted

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.8; to: 0.1; duration: 1600; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 0.1; to: 0.8; duration: 1600; easing.type: Easing.InOutSine }
                                }
                            }
                        }

                        // Card area
                        Rectangle {
                            id: card
                            anchors {
                                left: nodeDot.right; leftMargin: 10
                                right: parent.right; rightMargin: 4
                                top: parent.top; topMargin: 3
                                bottom: parent.bottom; bottomMargin: 3
                            }
                            radius: 6
                            color: genDelegate.isExpanded
                                ? Qt.rgba(1,1,1,0.07)
                                : (cardHover.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent")
                            border.color: genDelegate.isExpanded
                                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                                : "transparent"
                            border.width: 1
                            clip: true

                            MouseArea {
                                id: cardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.selectedGenNum === modelData.number) {
                                        root.selectedGenNum = -1
                                    } else {
                                        root.loadGenDetails(modelData.number)
                                    }
                                }
                            }

                            // Header row
                            RowLayout {
                                id: headerRow
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                anchors.margins: 8
                                height: genDelegate.headerH - 6
                                spacing: 6

                                // Gen number
                                Text {
                                    text: "#" + modelData.number
                                    color: (modelData.booted || modelData.active) ? root.accentColor : root.textColor
                                    font.pixelSize: Math.round(12 * root.fs); font.bold: true
                                    opacity: (modelData.booted || modelData.active) ? 1.0 : 0.85
                                }

                                // Timestamp
                                Text {
                                    text: modelData.timestamp
                                    color: root.textColor
                                    font.pixelSize: Math.round(9 * root.fs)
                                    opacity: 0.45
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Booted and Active status pills
                                RowLayout {
                                    spacing: 4

                                    // Booted pill
                                    Rectangle {
                                        visible: modelData.booted
                                        color: Qt.rgba(46/255, 204/255, 113/255, 0.15)
                                        border.color: "#2ecc71"; border.width: 1
                                        radius: 4; width: 52; height: 17

                                        Text {
                                            anchors.centerIn: parent
                                            text: i18n("Booted")
                                            color: "#2ecc71"
                                            font.pixelSize: Math.round(8 * root.fs); font.bold: true
                                        }
                                    }

                                    // Next Boot / Active pill
                                    Rectangle {
                                        visible: modelData.active && !modelData.booted
                                        color: Qt.rgba(230/255, 126/255, 34/255, 0.15)
                                        border.color: "#e67e22"; border.width: 1
                                        radius: 4; width: 64; height: 17

                                        Text {
                                            anchors.centerIn: parent
                                            text: i18n("Next Boot")
                                            color: "#e67e22"
                                            font.pixelSize: Math.round(8 * root.fs); font.bold: true
                                        }
                                    }
                                }

                                // Expand chevron – always visible
                                Rectangle {
                                    width: 22; height: 22; radius: 4
                                    color: genDelegate.isExpanded
                                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                                        : (cardHover.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        source: genDelegate.isExpanded ? "arrow-up" : "arrow-down"
                                        implicitWidth: 14; implicitHeight: 14
                                        color: genDelegate.isExpanded ? root.accentColor : root.textColor
                                        opacity: genDelegate.isExpanded ? 1.0 : (cardHover.containsMouse ? 0.8 : 0.5)
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                }
                            }

                            // ── Expanded details ──────────────────────────────
                            ColumnLayout {
                                visible: genDelegate.isExpanded
                                opacity: genDelegate.isExpanded ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: headerRow.bottom; topMargin: 2
                                    bottom: parent.bottom; bottomMargin: 6
                                }
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 6

                                // System info row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: i18n("Kernel")
                                            color: root.textColor; opacity: 0.4
                                            font.pixelSize: Math.round(8 * root.fs)
                                        }
                                        Text {
                                            text: root.detailsCache[modelData.number]
                                                ? root.detailsCache[modelData.number].kernelVer : "—"
                                            color: root.textColor
                                            font.pixelSize: Math.round(10 * root.fs); font.bold: true
                                            opacity: 0.9
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: i18n("NixOS Version")
                                            color: root.textColor; opacity: 0.4
                                            font.pixelSize: Math.round(8 * root.fs)
                                        }
                                        Text {
                                            text: root.detailsCache[modelData.number]
                                                ? root.detailsCache[modelData.number].nixosVer : "—"
                                            color: root.textColor
                                            font.pixelSize: Math.round(10 * root.fs); font.bold: true
                                            opacity: 0.9
                                            elide: Text.ElideRight
                                            width: parent.parent ? parent.parent.width * 0.45 : 80
                                        }
                                    }

                                    // Loading spinner for details – rotating NixOS logo
                                    Kirigami.Icon {
                                        id: detailsSpinner
                                        source: Qt.resolvedUrl("nixos-logo.svg")
                                        color: root.accentColor
                                        visible: root.isLoadingDetails && genDelegate.isExpanded
                                            && !root.detailsCache[modelData.number]
                                        implicitWidth: 20; implicitHeight: 20
                                        RotationAnimation on rotation {
                                            running: detailsSpinner.visible
                                            from: 0; to: 360
                                            duration: 1400
                                            loops: Animation.Infinite
                                        }
                                    }
                                }

                                // Actions row: rollback + optional delete
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Button {
                                        Layout.fillWidth: true
                                        text: modelData.booted
                                            ? i18n("✓ Currently booted")
                                            : (modelData.active
                                                ? i18n("⟳ Active – reboot to apply")
                                                : i18n("⬆ Boot into generation %1").arg(modelData.number))
                                        enabled: !modelData.booted && !modelData.active && !root.isBusy
                                        implicitHeight: 28
                                        font.pixelSize: Math.round(9 * root.fs); font.bold: true
                                        ToolTip.text: i18n("Switches the system profile to generation %1 and updates the bootloader entry. You must reboot to activate it.").arg(modelData.number)
                                        ToolTip.visible: hovered
                                        ToolTip.delay: 400
                                        onClicked: root.requestAction(modelData.number, "rollback")

                                        background: Rectangle {
                                            radius: 4
                                            color: parent.enabled
                                                ? (parent.hovered
                                                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                                                    : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15))
                                                : Qt.rgba(1,1,1,0.04)
                                            border.color: parent.enabled ? root.accentColor : Qt.rgba(1,1,1,0.1)
                                            border.width: 1
                                        }
                                        contentItem: RowLayout {
                                            anchors.centerIn: parent; spacing: 4
                                            Kirigami.Icon {
                                                source: modelData.booted ? "dialog-ok" : (modelData.active ? "dialog-ok-apply" : "system-reboot")
                                                implicitWidth: 12; implicitHeight: 12
                                                color: root.textColor
                                                opacity: parent.parent.enabled ? 0.8 : 0.35
                                            }
                                            Text {
                                                text: parent.parent.text
                                                color: parent.parent.enabled ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.4)
                                                font: parent.parent.font
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }

                                    // Delete button (optional)
                                    Button {
                                        visible: plasmoid.configuration.showDeleteButton && !modelData.active && !modelData.booted
                                        enabled: !root.isBusy && !modelData.active && !modelData.booted
                                        implicitWidth: 28; implicitHeight: 26
                                        ToolTip.text: i18n("Delete this generation permanently")
                                        ToolTip.visible: hovered
                                        ToolTip.delay: 600
                                        onClicked: root.requestAction(modelData.number, "delete")

                                        background: Rectangle {
                                            radius: 4
                                            color: parent.hovered ? Qt.rgba(1,0.2,0.2,0.25) : Qt.rgba(1,0.2,0.2,0.1)
                                            border.color: "#ff5555"; border.width: 1
                                        }
                                        contentItem: Kirigami.Icon {
                                            source: "edit-delete"
                                            implicitWidth: 14; implicitHeight: 14
                                            color: "#ff5555"
                                            anchors.centerIn: parent
                                        }
                                    }
                                }

                                // Package diff section
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: {
                                            const isBooted = modelData.booted
                                            const prev = root.getPreviousGen(modelData.number)
                                            if (isBooted) {
                                                 return prev ? i18n("Changes vs. previous (#%1)").arg(prev) : i18n("Changes vs. previous")
                                            } else {
                                                return root.diffMode === "booted"
                                                    ? i18n("Changes vs. booted (#%1)").arg(root.bootedGenNum)
                                                    : (prev ? i18n("Changes vs. previous (#%1)").arg(prev) : i18n("Changes vs. previous"))
                                            }
                                        }
                                        color: root.textColor
                                        font.pixelSize: Math.round(9 * root.fs); font.bold: true
                                        opacity: 0.5
                                    }

                                    ToolButton {
                                        visible: !modelData.booted && root.getPreviousGen(modelData.number) !== null
                                        icon.name: "document-compare"
                                        implicitWidth: 20; implicitHeight: 20
                                        ToolTip.text: root.diffMode === "booted" ? i18n("Compare vs. previous generation") : i18n("Compare vs. booted generation")
                                        ToolTip.visible: hovered
                                        onClicked: {
                                            root.diffMode = (root.diffMode === "booted" ? "prev" : "booted")
                                            // Clear details cache for this generation to force reload with new comparison base
                                            var cache = Object.assign({}, root.detailsCache)
                                            delete cache[modelData.number]
                                            root.detailsCache = cache
                                            root.loadGenDetails(modelData.number)
                                        }
                                    }

                                    // diff count badge
                                    Rectangle {
                                        visible: root.detailsCache[modelData.number]
                                            && root.detailsCache[modelData.number].diff.length > 0
                                        width: diffCountLabel.implicitWidth + 8; height: 14; radius: 7
                                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                                        border.color: root.accentColor; border.width: 1

                                        Text {
                                            id: diffCountLabel
                                            anchors.centerIn: parent
                                            text: root.detailsCache[modelData.number]
                                                ? root.detailsCache[modelData.number].diff.length : "0"
                                            color: root.accentColor
                                            font.pixelSize: Math.round(8 * root.fs); font.bold: true
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Filter field
                                    TextField {
                                        id: filterField
                                        visible: plasmoid.configuration.diffFilterEnabled
                                            && root.detailsCache[modelData.number]
                                            && root.detailsCache[modelData.number].diff.length > 0
                                        implicitWidth: 110; implicitHeight: 20
                                        font.pixelSize: Math.round(8 * root.fs)
                                        placeholderText: i18n("Filter…")
                                        leftPadding: 6; rightPadding: 6
                                        onTextChanged: root.diffFilter = text
                                        background: Rectangle {
                                            radius: 4
                                            color: Qt.rgba(1,1,1,0.06)
                                            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                                        }
                                        color: root.textColor
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 4
                                    color: Qt.rgba(0,0,0,0.18)
                                    border.color: Qt.rgba(1,1,1,0.05); border.width: 1
                                    clip: true

                                    ListView {
                                        id: diffView
                                        anchors.fill: parent; anchors.margins: 4
                                        clip: true; spacing: 2
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                        model: {
                                            if (!root.detailsCache[modelData.number]) return []
                                            const all = root.detailsCache[modelData.number].diff
                                            const f   = root.diffFilter.toLowerCase()
                                            return f ? all.filter(d => d.name.toLowerCase().indexOf(f) !== -1) : all
                                        }

                                        // Empty state
                                        Text {
                                            anchors.centerIn: parent
                                            visible: diffView.count === 0
                                            text: root.isLoadingDetails && !root.detailsCache[modelData.number]
                                                ? i18n("Loading diff…")
                                                : (root.diffFilter ? i18n("No matches") : i18n("No package changes"))
                                            color: root.textColor; font.pixelSize: Math.round(9 * root.fs)
                                            opacity: 0.4
                                        }

                                        delegate: RowLayout {
                                            width: diffView.width
                                            height: 18
                                            spacing: 5

                                            Rectangle {
                                                width: 14; height: 14; radius: 3
                                                color: modelData.type === "added"
                                                    ? Qt.rgba(0.2,0.85,0.2,0.18)
                                                    : (modelData.type === "removed"
                                                        ? Qt.rgba(0.85,0.2,0.2,0.18)
                                                        : Qt.rgba(0.85,0.6,0.2,0.18))
                                                border.color: modelData.type === "added" ? "#55cc55"
                                                    : (modelData.type === "removed" ? "#ff5555" : "#ffaa22")
                                                border.width: 0.5

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.type === "added" ? "+" : (modelData.type === "removed" ? "−" : "~")
                                                    color: parent.border.color
                                                    font.pixelSize: Math.round(8 * root.fs); font.bold: true
                                                }
                                            }

                                            Text {
                                                text: modelData.name
                                                color: root.textColor
                                                font.pixelSize: Math.round(9 * root.fs); font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.type === "added"
                                                    ? modelData.newVersion
                                                    : (modelData.type === "removed"
                                                        ? modelData.oldVersion
                                                        : modelData.oldVersion + " → " + modelData.newVersion)
                                                color: root.textColor; font.pixelSize: Math.round(8 * root.fs)
                                                opacity: 0.55; elide: Text.ElideRight
                                                Layout.maximumWidth: 110
                                            }

                                            Text {
                                                visible: modelData.size !== ""
                                                text: modelData.size
                                                color: root.textColor; font.pixelSize: Math.round(7 * root.fs)
                                                opacity: 0.35; elide: Text.ElideRight
                                                Layout.maximumWidth: 60
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Loading overlay – rotating NixOS logo
                Kirigami.Icon {
                    id: mainSpinner
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("nixos-logo.svg")
                    color: root.accentColor
                    visible: root.isLoadingGens && root.generations.length === 0
                    width: 64; height: 64
                    RotationAnimation on rotation {
                        running: mainSpinner.visible
                        from: 0; to: 360
                        duration: 1400
                        loops: Animation.Infinite
                    }
                }

                // Empty state
                Column {
                    anchors.centerIn: parent
                    visible: root.generations.length === 0 && !root.isLoadingGens
                    spacing: 8

                    Kirigami.Icon {
                        source: "dialog-warning"
                        implicitWidth: 36; implicitHeight: 36
                        opacity: 0.35
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: i18n("No generations found.\nCheck /nix/var/nix/profiles/ exists\nand the widget has read access.")
                        color: root.textColor; font.pixelSize: Math.round(10 * root.fs)
                        opacity: 0.4; horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap; width: 240
                    }
                    Button {
                        text: i18n("Retry")
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Math.round(9 * root.fs)
                        onClicked: root.refreshGenerations()
                    }
                }
            }
        }

        // ── Flake updates popup ───────────────────────────────────────────────
        Popup {
            id: flakePopup
            anchors.centerIn: parent
            width: Math.min(400, parent.width - 24)
            height: Math.min(340, parent.height - 48)
            modal: true; focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                radius: 10
                color: plasmoid.configuration.showBg
                    ? (plasmoid.configuration.bgColor || "#d90d0f1a")
                    : Kirigami.Theme.backgroundColor
                border.color: Qt.rgba(1,1,1,0.12); border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Kirigami.Icon { source: "update-none"; implicitWidth: 18; implicitHeight: 18; color: "#cc88ff" }
                    Text {
                        text: i18n("Pending Flake Lock Updates")
                        color: root.textColor; font.pixelSize: Math.round(12 * root.fs); font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    ToolButton {
                        icon.name: "window-close"
                        onClicked: flakePopup.close()
                        implicitWidth: 24; implicitHeight: 24
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.1) }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 6
                    model: root.flakeUpdates
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Text {
                        anchors.centerIn: parent
                        visible: root.flakeUpdates.length === 0
                        text: i18n("No updates available")
                        color: root.textColor; font.pixelSize: Math.round(10 * root.fs); opacity: 0.4
                    }

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 42; radius: 5
                        color: Qt.rgba(1,1,1,0.03)
                        border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 10
                            Column {
                                Layout.fillWidth: true; spacing: 2
                                Text {
                                    text: modelData.input
                                    color: root.textColor
                                    font.pixelSize: Math.round(10 * root.fs); font.bold: true
                                }
                                Text {
                                    text: modelData.oldDate + "  →  " + modelData.newDate
                                    color: root.textColor; font.pixelSize: Math.round(8 * root.fs); opacity: 0.45
                                }
                            }
                            Column {
                                spacing: 2
                                Text {
                                    text: modelData.oldRev
                                    color: root.textColor; font.pixelSize: Math.round(8 * root.fs)
                                    opacity: 0.5; font.family: "monospace"
                                }
                                Text {
                                    text: modelData.newRev
                                    color: "#cc88ff"; font.pixelSize: Math.round(8 * root.fs)
                                    font.bold: true; font.family: "monospace"
                                }
                            }
                            ToolButton {
                                visible: modelData.url && modelData.url !== ""
                                icon.name: "internet-web-browser"
                                implicitWidth: 26; implicitHeight: 26
                                ToolTip.text: modelData.url || ""
                                ToolTip.visible: hovered
                                ToolTip.delay: 400
                                onClicked: Qt.openUrlExternally(modelData.url)
                            }
                        }
                    }
                }

                Text {
                    text: i18n("Run 'nix flake update' in your config directory to apply.")
                    color: root.textColor; font.pixelSize: Math.round(8 * root.fs); opacity: 0.38
                    horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
