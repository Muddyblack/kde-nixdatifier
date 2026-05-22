import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "components"

PlasmoidItem {
    id: root

    // ── Size hints ────────────────────────────────────────────────────────────
    Layout.minimumWidth: 360
    Layout.preferredWidth: plasmoid.configuration.popupWidth
    Layout.minimumHeight: 340
    Layout.preferredHeight: plasmoid.configuration.popupHeight

    Plasmoid.backgroundHints: plasmoid.configuration.showBg ? "NoBackground" : "DefaultBackground"
    property bool pinned: false
    hideOnWindowDeactivate: !pinned

    // Save popup size when it closes so it reopens at the same dimensions
    property int _lastWidth: 0
    property int _lastHeight: 0

    onWidthChanged: if (expanded) {
        _lastWidth = width;
        _lastHeight = height;
    }
    onHeightChanged: if (expanded) {
        _lastWidth = width;
        _lastHeight = height;
    }

    // ── Script directory ──────────────────────────────────────────────────────
    readonly property string scriptDir: Qt.resolvedUrl("../tools/sh/").toString().replace("file://", "")

    // ── Theme / Config aliases ────────────────────────────────────────────────
    readonly property color accentColor: plasmoid.configuration.accentColor || Kirigami.Theme.highlightColor
    readonly property color timelineColor: plasmoid.configuration.timelineColor || "#9b5de5"
    readonly property color textColor: plasmoid.configuration.useSystemTextColor ? Kirigami.Theme.textColor : (plasmoid.configuration.customTextColor || "#ffffff")
    readonly property string flakePath: plasmoid.configuration.flakePath || ""
    readonly property real fs: plasmoid.configuration.fontScale || 1.0
    readonly property var customCommands: {
        try {
            return JSON.parse(plasmoid.configuration.customCommands || "[]");
        } catch (e) {
            return [];
        }
    }
    // Empty string = auto-detect from KDE/XDG defaults in the terminal script
    readonly property string terminalApp: plasmoid.configuration.commandTerminal || ""
    readonly property string iconStyle: plasmoid.configuration.iconStyle || "colored"

    // ── Generations state ─────────────────────────────────────────────────────
    property var generations: []
    property string activeStorePath: ""
    property string bootedStorePath: ""
    property int activeGenNum: -1
    property int bootedGenNum: -1
    property int selectedGenNum: -1
    property bool isLoadingGens: false
    property bool isLoadingDetails: false
    property bool isBusy: false
    property var detailsCache: ({})
    property string diffFilter: ""
    property string diffMode: "booted"

    // Cache of pairwise diffs for the Diff tab: key "A_B" -> { diff: [...] }
    property var pairDiffCache: ({})
    property bool isLoadingPairDiff: false
    property int pairDiffA: -1
    property int pairDiffB: -1

    // Icon cache: pkgName -> icon string (system theme name or "")
    property var iconCache: ({})

    // Meta cache: pkgName -> { url, source }
    //   source = "nixpkgs" | "plasmoid" | ""   ("" means we looked it up and
    //   found nothing — used to suppress repeated lookups)
    property var metaCache: ({})

    // ── Action tracking (exposed to FullView for busy bar text) ───────────────
    property string currentActionType: ""
    property int currentActionGenNum: -1

    // ── Flake state ───────────────────────────────────────────────────────────
    property var flakeUpdates: []
    property bool isCheckingFlake: false
    property string lastFlakeCheckTime: ""

    // ── System info ───────────────────────────────────────────────────────────
    property string hostname: ""
    property string nixosVersion: ""
    property string lastActivationTime: ""
    property string uptime: ""

    // ── Disk usage state ──────────────────────────────────────────────────────
    // All values in bytes (0 = unknown).
    property real diskStoreBytes: 0
    property real diskReclaimableBytes: 0
    property real diskFreeBytes: 0

    // ── Secrets state ─────────────────────────────────────────────────────────
    // deployedSecrets: live decrypted secrets (e.g. /run/secrets, auto-detected)
    // sourceSecrets:   encrypted source file (e.g. secrets.yaml in the flake repo)
    property var deployedSecrets: ({
            path: "",
            exists: false,
            lastModified: "",
            freshness: "",
            fileCount: 0,
            names: [],
            encKind: "",
            sopsVersion: "",
            recipientCount: 0,
            encType: ""
        })
    property var sourceSecrets: ({
            path: "",
            exists: false,
            lastModified: "",
            freshness: "",
            fileCount: 0,
            names: [],
            encKind: "",
            sopsVersion: "",
            recipientCount: 0,
            encType: ""
        })

    // Legacy alias so any remaining sopsStatus references still compile
    property var sopsStatus: deployedSecrets

    // ── Hash tool state ───────────────────────────────────────────────────────
    property var hashResult: null   // { value: string, isError: bool } | null

    // ── Pending confirmation ──────────────────────────────────────────────────
    property int pendingGenNum: -1
    property string pendingAction: ""

    // ── View state ────────────────────────────────────────────────────────────
    property string activeViewMode: plasmoid.configuration.defaultView || "timeline"

    // ── Toast queue ───────────────────────────────────────────────────────────
    property var toasts: []

    function pushToast(message, isError) {
        var arr = root.toasts.slice();
        arr.push({
            msg: message,
            err: isError || false,
            id: Date.now()
        });
        root.toasts = arr;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 5000
        repeat: false
        onTriggered: {
            var arr = root.toasts.slice();
            for (var i = 0; i < arr.length; i++) {
                if (!arr[i].err) {
                    arr.splice(i, 1);
                    break;
                }
            }
            root.toasts = arr;
            for (var j = 0; j < arr.length; j++) {
                if (!arr[j].err) {
                    restart();
                    return;
                }
            }
        }
    }

    TextEdit {
        id: clipboardHelper
        visible: false
    }

    function copyToClipboard(text) {
        clipboardHelper.text = text;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        root.pushToast(i18n("Copied to clipboard"), false);
    }

    // Desktop notification — survives popup close. Respects user's preference.
    // Uses notify-send (xdg-compatible) and an appropriate themed icon.
    function notify(title, body, isError) {
        if (!plasmoid.configuration.showNotifications)
            return;
        const icon = isError ? "dialog-error" : "system-software-update";
        sh("notify-send -i " + icon + " " + shq(title) + " " + shq(body), null);
    }

    // Human-readable byte formatter — used for closure size + disk usage chips.
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

    // ── Shell helper ──────────────────────────────────────────────────────────
    // Creates a fresh Shell.qml instance, runs cmd, calls cb(cmd,out,err,code), auto-cleans up.
    function sh(cmd, cb) {
        const c = Qt.createComponent("components/Shell.qml");
        if (c.status !== Component.Ready) {
            pushToast(i18n("Shell component error: %1").arg(c.errorString()), true);
            return;
        }
        const obj = c.createObject(root);
        obj.exec(cmd, cb);
    }

    // Wrap a value as a single-quoted POSIX-shell literal. Returns `'…'` so
    // callers concatenate without adding their own quotes. Any embedded
    // single quote is closed, re-opened with an escaped quote, and the literal
    // resumes — the canonical safe-quoting idiom.
    // Use this for EVERY user/config/derivation-sourced string that becomes
    // part of a shell command. Concatenating with bare `'…'` plus `.replace`
    // is fragile and has been removed.
    function shq(value) {
        return "'" + String(value == null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    // ── Operations ────────────────────────────────────────────────────────────

    function refreshGenerations() {
        if (root.isLoadingGens)
            return;
        root.isLoadingGens = true;
        sh(root.scriptDir + "generations", function (cmd, out, err, code) {
            root.isLoadingGens = false;
            const text = (out || "").trim();
            if (!text) {
                root.pushToast(i18n("No generations found — is /nix/var/nix/profiles/ accessible?"), true);
                return;
            }
            root.parseGenerations(text);
        });
    }

    function probeSysInfo() {
        sh(root.scriptDir + "sysinfo", function (cmd, out, err, code) {
            root.parseSysInfo(out || "");
        });
    }

    function probeDiskUsage() {
        sh(root.scriptDir + "diskusage", function (cmd, out, err, code) {
            const p = (out || "").split("\x1e");
            root.diskStoreBytes = parseInt((p[0] || "").trim(), 10) || 0;
            root.diskReclaimableBytes = parseInt((p[1] || "").trim(), 10) || 0;
            root.diskFreeBytes = parseInt((p[2] || "").trim(), 10) || 0;
        });
    }

    function probeSecrets() {
        sh(root.scriptDir + "secrets " + shq(plasmoid.configuration.secretsPath) + " " + shq(plasmoid.configuration.secretsSourcePath) + " " + shq(root.flakePath), function (cmd, out, err, code) {
            root.parseSopsInfo(out || "");
        });
    }

    function runHashProbe(mode, input) {
        root.hashResult = null;
        // mode comes from a fixed 5-string allowlist in the UI, but guard
        // defensively in case a future caller passes something else.
        const allowed = {
            url: 1,
            zip: 1,
            github: 1,
            file: 1,
            store: 1
        };
        if (!allowed[mode]) {
            root.hashResult = {
                value: "ERROR: invalid hash mode",
                isError: true
            };
            return;
        }
        sh(root.scriptDir + "hash " + shq(mode) + " " + shq(input), function (cmd, out, err, code) {
            const raw = (out || "").trim();
            const isError = raw.startsWith("ERROR:");
            root.hashResult = {
                value: raw,
                isError: isError
            };
        });
    }

    function getPreviousGen(genNum) {
        for (let i = 0; i < root.generations.length; i++) {
            if (root.generations[i].number === genNum) {
                return (i + 1 < root.generations.length) ? root.generations[i + 1].number : null;
            }
        }
        return null;
    }

    function loadGenDetails(genNum) {
        // Coerce to a strict positive integer — genNum is then safe to splice
        // into shell paths without further escaping.
        genNum = parseInt(genNum, 10);
        if (!(genNum > 0))
            return;
        if (root.detailsCache[genNum] !== undefined) {
            root.selectedGenNum = genNum;
            return;
        }
        if (root.isLoadingDetails)
            return;
        root.isLoadingDetails = true;

        const link = "/nix/var/nix/profiles/system-" + genNum + "-link";
        let isBooted = false;
        for (let i = 0; i < root.generations.length; i++) {
            if (root.generations[i].number === genNum) {
                isBooted = root.generations[i].booted;
                break;
            }
        }

        let basePath;
        if (isBooted) {
            const prev = root.getPreviousGen(genNum);
            basePath = prev !== null ? "/nix/var/nix/profiles/system-" + prev + "-link" : link;
        } else if (root.diffMode === "booted") {
            const bp = root.bootedStorePath !== "" ? root.bootedStorePath : root.activeStorePath;
            basePath = bp !== "" ? bp : link;
        } else {
            const prev = root.getPreviousGen(genNum);
            basePath = prev !== null ? "/nix/var/nix/profiles/system-" + prev + "-link" : link;
        }

        sh(root.scriptDir + "details '" + link + "' '" + basePath + "'", function (cmd, out, err, code) {
            root.isLoadingDetails = false;
            root.parseDetails(genNum, out || "");
        });
    }

    function comparePair(genA, genB) {
        genA = parseInt(genA, 10);
        genB = parseInt(genB, 10);
        if (!(genA > 0) || !(genB > 0) || genA === genB)
            return;
        root.pairDiffA = genA;
        root.pairDiffB = genB;
        const key = genA + "_" + genB;
        if (root.pairDiffCache[key] !== undefined)
            return;
        if (root.isLoadingPairDiff)
            return;
        root.isLoadingPairDiff = true;
        const linkA = "/nix/var/nix/profiles/system-" + genA + "-link";
        const linkB = "/nix/var/nix/profiles/system-" + genB + "-link";
        // base = B, target = A → diff shows what A has on top of B
        sh(root.scriptDir + "details '" + linkA + "' '" + linkB + "'", function (cmd, out, err, code) {
            root.isLoadingPairDiff = false;
            root.parsePairDiff(genA, genB, out || "");
        });
    }

    function parsePairDiff(genA, genB, text) {
        const lines = text.split("\n");
        const diffList = [];
        for (let i = 4; i < lines.length; i++) {
            const line = stripAnsi(lines[i]).trim();
            if (!line)
                continue;
            const m = line.match(/^([^:]+):\s+(\S+)\s+(?:→|->)\s+([^\s,]+)(?:,\s+(.+))?/);
            if (m) {
                const oldV = m[2];
                const newV = m[3];
                let type = "upgrade";
                if (oldV === "∅" || oldV === "null")
                    type = "added";
                else if (newV === "∅" || newV === "null")
                    type = "removed";
                diffList.push({
                    name: m[1].trim(),
                    oldVersion: oldV,
                    newVersion: newV,
                    size: (m[4] || "").trim(),
                    type
                });
            }
        }
        const cache = Object.assign({}, root.pairDiffCache);
        cache[genA + "_" + genB] = {
            diff: diffList
        };
        root.pairDiffCache = cache;
        root.loadIcons(diffList);
        root.loadMeta(diffList);
    }

    function loadIcons(diffList) {
        if (!plasmoid.configuration.showPackageIcons)
            return;
        const unknown = diffList.map(d => d.name).filter(n => !(n in root.iconCache));
        if (unknown.length === 0)
            return;
        const input = unknown.join("\n");
        sh("printf %s " + shq(input) + " | " + root.scriptDir + "icons", function (cmd, out, err, code) {
            const updated = Object.assign({}, root.iconCache);
            (out || "").split("\n").forEach(line => {
                const tab = line.indexOf("\t");
                if (tab > 0)
                    updated[line.substring(0, tab)] = line.substring(tab + 1).trim();
            });
            unknown.forEach(n => {
                if (!(n in updated))
                    updated[n] = "";
            });
            root.iconCache = updated;
        });
    }

    // Resolve a real upstream homepage for each package — meta.homepage from
    // nixpkgs, or the Website field of a plasmoid metadata.json. One shell call
    // covers the whole diff (the eval is batched). Packages with no link found
    // are cached with source="" so we don't re-probe them.
    function loadMeta(diffList) {
        const unknown = diffList.map(d => d.name).filter(n => n && !(n in root.metaCache));
        if (unknown.length === 0)
            return;
        const input = unknown.join("\n");
        sh("printf %s " + shq(input) + " | " + root.scriptDir + "meta", function (cmd, out, err, code) {
            const updated = Object.assign({}, root.metaCache);
            (out || "").split("\n").forEach(line => {
                const parts = line.split("\t");
                if (parts.length >= 3 && parts[0])
                    updated[parts[0]] = {
                        url: parts[1],
                        source: parts[2]
                    };
            });
            unknown.forEach(n => {
                if (!(n in updated))
                    updated[n] = {
                        url: "",
                        source: ""
                    };
            });
            root.metaCache = updated;
        });
    }

    function checkFlakeUpdates(isRetry) {
        if (root.isCheckingFlake || root.flakePath === "")
            return;
        root.isCheckingFlake = true;
        sh(root.scriptDir + "flake-probe " + shq(root.flakePath), function (cmd, out, err, code) {
            root.isCheckingFlake = false;
            if (code !== 0) {
                const msg = (err || out || "").trim() || i18n("flake-probe failed");
                root.pushToast(msg, true);
                return;
            }
            root.parseFlakeProbe(out || "", !!isRetry);
        });
    }

    function parseFlakeProbe(text, isRetry) {
        const lines = text.split("\n");
        const updates = [];
        const unreachable = [];

        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t");
            if (parts.length < 6)
                continue;
            const name = parts[0];
            const status = parts[1];
            const oldRev = parts[2];
            const newRev = parts[3];
            const oldDateTs = parseInt(parts[4]) || 0;
            const url = parts[5];
            if (!name)
                continue;

            if (status === "unreachable") {
                unreachable.push(name);
                continue;
            }
            if (status !== "ok")
                continue;

            updates.push({
                input: name,
                oldRev: oldRev.substring(0, 7),
                newRev: newRev.substring(0, 7),
                oldDate: oldDateTs > 0 ? new Date(oldDateTs * 1000).toLocaleDateString() : "",
                newDate: i18n("latest"),
                url: url.replace(/\.git$/, "")
            });
        }

        root.flakeUpdates = updates;
        root.lastFlakeCheckTime = new Date().toLocaleTimeString();

        // Transient network blips (network not up yet, GitHub anon rate-limit, brief DNS hiccup)
        // are common on the first probe after login. Silently retry once; only toast if it
        // still fails. After the retry succeeds, that recurrence will hit this branch with
        // no unreachable items, so the toast never fires.
        if (unreachable.length > 0) {
            if (!isRetry) {
                flakeRetryTimer.restart();
            } else {
                root.pushToast(i18n("Could not reach: %1").arg(unreachable.join(", ")), true);
            }
        }

        if (updates.length > 0)
            root.notify(i18n("NixOS — flake updates available"), i18np("%1 flake input has updates available", "%1 flake inputs have updates available", updates.length), false);
    }

    Timer {
        id: flakeRetryTimer
        interval: 15000
        repeat: false
        onTriggered: root.checkFlakeUpdates(true)
    }

    function runCustomCommand(cmd, label) {
        const workDir = root.flakePath !== "" ? root.flakePath : "~";
        // cmd is the user's own custom command (from plasmoid config), so we
        // pass it verbatim — escaping it would break legitimate uses like
        // pipelines and quoted args. terminalApp and workDir are NOT meant
        // to be shell expressions, so they get quoted.
        sh(root.scriptDir + "terminal " + shq(root.terminalApp) + " " + shq(workDir) + " " + shq(cmd), null);
        root.pushToast(i18n("Launching: %1").arg(label), false);
        // Start watching for a new generation. The external command runs in a terminal
        // we don't control, so we infer success from the system profile growing.
        cmdWatcher.label = label;
        cmdWatcher.baselineCount = root.generations.length;
        cmdWatcher.baselineActiveNum = root.activeGenNum;
        cmdWatcher.elapsed = 0;
        cmdWatcher.restart();
    }

    // Polls every 10s for up to 30 min after a custom command launch, firing a
    // notification + refresh when a new generation appears.
    Timer {
        id: cmdWatcher
        interval: 10000
        repeat: true
        property string label: ""
        property int baselineCount: 0
        property int baselineActiveNum: 0
        property int elapsed: 0
        onTriggered: {
            elapsed += interval;
            // Refresh the gen list to see if it grew.
            sh(root.scriptDir + "generations", function (cmd, out, err, code) {
                const text = (out || "").trim();
                if (!text)
                    return;
                // Count non-empty data lines (mirrors parseGenerations: skip first 1-2 header rows).
                const lines = text.split("\n").filter(l => l.trim() !== "");
                const count = lines.length > 1 ? lines.length - 1 : 0;
                if (count > cmdWatcher.baselineCount) {
                    cmdWatcher.stop();
                    root.refreshGenerations();
                    root.probeDiskUsage();
                    root.notify(i18n("NixOS — %1 finished").arg(cmdWatcher.label), i18n("A new system generation is available."), false);
                }
            });
            if (elapsed >= 30 * 60 * 1000)
                stop();
        }
    }

    function requestAction(genNum, action) {
        if (root.isBusy) {
            root.pushToast(i18n("Already running another action — please wait."), true);
            return;
        }
        const needsConfirm = (action === "rollback" || action === "switch") ? plasmoid.configuration.confirmBeforeRollback : plasmoid.configuration.confirmBeforeDelete;
        if (needsConfirm) {
            root.pendingGenNum = genNum;
            root.pendingAction = action;
        } else {
            executeAction(genNum, action);
        }
    }

    function cancelPendingAction() {
        root.pendingGenNum = -1;
        root.pendingAction = "";
    }

    function confirmPendingAction() {
        if (root.pendingGenNum > 0 && root.pendingAction !== "") {
            const g = root.pendingGenNum;
            const a = root.pendingAction;
            root.pendingGenNum = -1;
            root.pendingAction = "";
            executeAction(g, a);
        }
    }

    function executeAction(genNum, action) {
        if (root.isBusy)
            return;
        // CRITICAL: this builds a command that runs under `pkexec` (root).
        // Reject anything that isn't a clean positive int or a known action
        // before it can reach the shell-string concatenation below.
        genNum = parseInt(genNum, 10);
        if (!(genNum > 0))
            return;
        if (action !== "switch" && action !== "rollback" && action !== "delete")
            return;
        root.isBusy = true;
        root.currentActionType = action;
        root.currentActionGenNum = genNum;

        const prefix = plasmoid.configuration.usePkexec ? "pkexec " : "";
        const pathExport = "export PATH=$PATH:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin; ";
        const profileSwitch = prefix + "nix-env --profile /nix/var/nix/profiles/system --switch-generation " + genNum;

        let cmd;
        if (action === "switch") {
            cmd = "sh -c \"" + pathExport + profileSwitch + " && " + prefix + "/nix/var/nix/profiles/system/bin/switch-to-configuration switch 2>&1\"";
        } else if (action === "rollback") {
            cmd = "sh -c \"" + pathExport + profileSwitch + " && " + prefix + "/nix/var/nix/profiles/system/bin/switch-to-configuration boot 2>&1\"";
        } else {
            cmd = "sh -c \"" + pathExport + prefix + "nix-env --profile /nix/var/nix/profiles/system --delete-generations " + genNum + " 2>&1\"";
        }

        sh(cmd, function (c, out, err, code) {
            root.isBusy = false;
            if (code !== 0) {
                const msg = (err || out || "").trim();
                const labels = {
                    switch: i18n("Live switch failed: "),
                    rollback: i18n("Set-next-boot failed: "),
                    delete: i18n("Delete failed: ")
                };
                root.pushToast((labels[action] || "") + msg, true);
                return;
            }
            const ok = {
                switch: i18n("Generation %1 is now active."),
                rollback: i18n("Generation %1 set for next boot. Reboot to activate."),
                delete: i18n("Generation %1 deleted.")
            };
            const okTitle = {
                switch: i18n("NixOS — generation activated"),
                rollback: i18n("NixOS — next boot set"),
                delete: i18n("NixOS — generation deleted")
            };
            root.pushToast(ok[action].arg(genNum), false);
            root.notify(okTitle[action], ok[action].arg(genNum), false);
            if (action === "delete" && root.selectedGenNum === genNum)
                root.selectedGenNum = -1;
            root.refreshGenerations();
            root.probeDiskUsage();
        });
    }

    // ── Parsers ───────────────────────────────────────────────────────────────

    function parseGenerations(text) {
        const lines = text.split("\n");

        let activePath = "";
        let bootedPath = "";
        let startIdx = 0;
        if (lines[0] && (lines[0].startsWith("/nix/store/") || lines[0].startsWith("/nix/var/"))) {
            activePath = lines[0].trim();
            startIdx = 1;
            if (lines[1] && (lines[1].startsWith("/nix/store/") || lines[1].startsWith("/nix/var/"))) {
                bootedPath = lines[1].trim();
                startIdx = 2;
            }
        }
        root.activeStorePath = activePath;
        root.bootedStorePath = bootedPath;

        const list = [];
        let activeNum = -1;
        let bootedNum = -1;
        for (let i = startIdx; i < lines.length; i++) {
            const m = lines[i].match(/^([\d-]+ [\d:]+)\.\d+ [+-]\d+ '([^']*system-(\d+)-link)' -> '([^']+)'/);
            if (!m)
                continue;
            const genNum = parseInt(m[3]);
            const storePath = m[4];
            const isActive = activePath !== "" && storePath === activePath;
            const isBooted = bootedPath !== "" && storePath === bootedPath;
            if (isActive)
                activeNum = genNum;
            if (isBooted)
                bootedNum = genNum;
            list.push({
                number: genNum,
                timestamp: m[1],
                storePath,
                active: isActive,
                booted: isBooted
            });
        }

        list.sort((a, b) => b.number - a.number);

        if (activeNum === -1 && list.length > 0) {
            activeNum = list[0].number;
            list[0].active = true;
        }

        // Keep only the highest generation matching the booted store path
        let maxBooted = list.reduce((max, g) => g.booted && g.number > max ? g.number : max, -1);
        if (maxBooted === -1)
            maxBooted = activeNum;
        bootedNum = maxBooted;
        for (let i = 0; i < list.length; i++)
            list[i].booted = (list[i].number === bootedNum);

        const maxG = Math.max(3, plasmoid.configuration.maxGenerations || 10);
        if (list.length > maxG)
            list.splice(maxG);

        root.generations = list;
        root.activeGenNum = activeNum;
        root.bootedGenNum = bootedNum;

        root.probeSysInfo();
    }

    function stripAnsi(s) {
        return s.replace(/\x1b\[[0-9;]*[mGKHFABCDEFJRSTsu]/g, "");
    }

    function parseDetails(genNum, text) {
        // \x1e separates: [0]=nixos-version  [1]=kernel-path  [2]=diff lines
        const parts = text.split("\x1e");
        const nixosVer = stripAnsi((parts[0] || "").trim());
        const kernelPath = stripAnsi((parts[1] || "").trim());
        const kMatch = kernelPath.match(/linux-([^/]+)/);
        const kernelVer = kMatch ? kMatch[1] : (kernelPath ? kernelPath.split("/").slice(-2, -1)[0] : "—");
        const diffRaw = parts[2] || "";
        const sizeRaw = (parts[3] || "").trim();
        const closureBytes = /^\d+$/.test(sizeRaw) ? parseInt(sizeRaw, 10) : 0;

        const diffList = [];
        const lines = diffRaw.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = stripAnsi(lines[i]).trim();
            if (!line)
                continue;
            const m = line.match(/^([^:]+):\s+(\S+)\s+(?:→|->)\s+([^\s,]+)(?:,\s+(.+))?/);
            if (m) {
                const oldV = m[2];
                const newV = m[3];
                let type = "upgrade";
                if (oldV === "∅" || oldV === "null")
                    type = "added";
                else if (newV === "∅" || newV === "null")
                    type = "removed";
                diffList.push({
                    name: m[1].trim(),
                    oldVersion: oldV,
                    newVersion: newV,
                    size: (m[4] || "").trim(),
                    type
                });
            }
        }

        // Extract commit date from nixos version e.g. "25.11.20260518.abc1234"
        let commitDate = "";
        const dateM = nixosVer.match(/(\d{4})(\d{2})(\d{2})/);
        if (dateM)
            commitDate = dateM[1] + "-" + dateM[2] + "-" + dateM[3];

        const cache = Object.assign({}, root.detailsCache);
        cache[genNum] = {
            nixosVer,
            kernelVer,
            commitDate,
            diff: diffList,
            closureBytes
        };
        root.detailsCache = cache;
        root.loadIcons(diffList);
        root.loadMeta(diffList);
        root.selectedGenNum = genNum;
    }

    function parseSysInfo(text) {
        const p = text.split("---");
        root.hostname = p[0] ? p[0].trim() : "";
        root.nixosVersion = p[1] ? p[1].trim() : "";
        root.uptime = p[2] ? p[2].trim() : "";
        root.lastActivationTime = p[3] ? p[3].trim() : "";
    }

    function parseSopsInfo(text) {
        const blocks = text.split("===");
        root.deployedSecrets = parseSecretsBlock(blocks[0] || "", "deployed");
        root.sourceSecrets = parseSecretsBlock(blocks[1] || "", "source");
    }

    function parseSecretsBlock(raw, kind) {
        const empty = {
            path: "",
            exists: false,
            lastModified: "",
            freshness: "",
            fileCount: 0,
            names: [],
            encKind: "",
            sopsVersion: "",
            recipientCount: 0,
            encType: ""
        };
        // Preserve a leading empty line (path=empty) by only trimming, not filtering.
        const rawLines = raw.split("\n").map(l => l.trim());
        // Drop leading blank lines AND trailing blank lines, keep blanks in between.
        let start = 0;
        while (start < rawLines.length && rawLines[start] === "")
            start++;
        // If the first non-blank line is a status keyword, the path field was empty.
        if (start >= rawLines.length || rawLines[start] === "missing")
            return empty;
        const lines = rawLines.slice(start).filter(l => l !== "");
        if (lines.length < 2)
            return empty;
        const sep = lines.indexOf("---");
        const exists = lines[1] === "exists";
        const lastModified = (sep > 2) ? lines[2] : "";
        const names = lines.filter(l => l.startsWith("name:")).map(l => l.slice(5));

        if (kind === "deployed") {
            const freshness = (sep >= 0 && lines.length > sep + 1) ? lines[sep + 1] : "";
            const fileCount = (sep >= 0 && lines.length > sep + 2) ? (parseInt(lines[sep + 2]) || 0) : 0;
            return {
                path: lines[0],
                exists,
                lastModified,
                freshness,
                fileCount,
                names,
                encKind: "",
                sopsVersion: "",
                recipientCount: 0,
                encType: ""
            };
        } else {
            const encKind = (sep >= 0 && lines.length > sep + 1) ? lines[sep + 1] : "";
            const sopsVersion = (sep >= 0 && lines.length > sep + 2) ? lines[sep + 2] : "";
            const recipientCount = (sep >= 0 && lines.length > sep + 3) ? (parseInt(lines[sep + 3]) || 0) : 0;
            const encType = (sep >= 0 && lines.length > sep + 4) ? lines[sep + 4] : "";
            return {
                path: lines[0],
                exists,
                lastModified,
                freshness: "",
                fileCount: names.length,
                names,
                encKind,
                sopsVersion,
                recipientCount,
                encType
            };
        }
    }

    // ── Init & timers ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        refreshGenerations();
        probeSysInfo();
        probeSecrets();
        probeDiskUsage();
        if (root.flakePath !== "")
            initialFlakeCheckTimer.start();
    }

    // The widget loads as soon as Plasma starts the panel — often before NetworkManager
    // has come up. Defer the very first flake probe to give the network a chance.
    // (The recurring timer below still fires on its own schedule.)
    Timer {
        id: initialFlakeCheckTimer
        interval: 30000
        repeat: false
        onTriggered: root.checkFlakeUpdates()
    }

    onExpandedChanged: {
        if (expanded) {
            if (plasmoid.configuration.autoRefreshOnOpen) {
                refreshGenerations();
                probeSysInfo();
                probeDiskUsage();
            }
        } else {
            // Persist the size the user left the popup at
            if (_lastWidth >= 360 && _lastHeight >= 340) {
                plasmoid.configuration.popupWidth = _lastWidth;
                plasmoid.configuration.popupHeight = _lastHeight;
            }
        }
    }

    Timer {
        interval: Math.max(60, plasmoid.configuration.checkInterval || 3600) * 1000
        running: root.flakePath !== ""
        repeat: true
        onTriggered: root.checkFlakeUpdates()
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.probeSysInfo()
    }

    // Disk usage is expensive (du + nix-collect-garbage --dry-run) — poll slowly.
    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: root.probeDiskUsage()
    }

    // ── Compact representation ────────────────────────────────────────────────
    compactRepresentation: CompactView {
        accentColor: root.accentColor
        textColor: root.textColor
        activeGenNum: root.activeGenNum
        flakeUpdates: root.flakeUpdates
        isBusy: root.isBusy
        isLoadingGens: root.isLoadingGens
        compactStyle: plasmoid.configuration.compactStyle || "icon"
        compactShowBadge: plasmoid.configuration.compactShowBadge
        iconStyle: root.iconStyle
        onToggleExpanded: root.expanded = !root.expanded
    }

    // ── Full representation ───────────────────────────────────────────────────
    fullRepresentation: FullView {
        accentColor: root.accentColor
        timelineColor: root.timelineColor
        textColor: root.textColor
        fs: root.fs
        showBg: plasmoid.configuration.showBg
        bgColor: Qt.color(plasmoid.configuration.bgColor || "#800a0c14")
        bgRadius: plasmoid.configuration.bgRadius || 14
        isBusy: root.isBusy
        isLoadingGens: root.isLoadingGens
        isLoadingDetails: root.isLoadingDetails
        isCheckingFlake: root.isCheckingFlake
        generations: root.generations
        flakeUpdates: root.flakeUpdates
        toasts: root.toasts
        lastFlakeCheckTime: root.lastFlakeCheckTime
        activeGenNum: root.activeGenNum
        bootedGenNum: root.bootedGenNum
        selectedGenNum: root.selectedGenNum
        detailsCache: root.detailsCache
        diffFilter: root.diffFilter
        diffMode: root.diffMode
        showDeleteButton: plasmoid.configuration.showDeleteButton
        diffFilterEnabled: plasmoid.configuration.diffFilterEnabled
        showFlakeSection: plasmoid.configuration.showFlakeSection
        showCommandButtons: plasmoid.configuration.showCommandButtons
        customCommands: root.customCommands
        actionType: root.currentActionType
        actionGenNum: root.currentActionGenNum
        activeViewMode: root.activeViewMode
        sopsStatus: root.sopsStatus
        deployedSecrets: root.deployedSecrets
        sourceSecrets: root.sourceSecrets
        hostname: root.hostname
        nixosVersion: root.nixosVersion
        lastActivationTime: root.lastActivationTime
        uptime: root.uptime
        diskStoreBytes: root.diskStoreBytes
        diskReclaimableBytes: root.diskReclaimableBytes
        diskFreeBytes: root.diskFreeBytes
        hashResult: root.hashResult
        pendingGenNum: root.pendingGenNum
        pendingAction: root.pendingAction
        usePkexec: plasmoid.configuration.usePkexec
        pairDiffCache: root.pairDiffCache
        isLoadingPairDiff: root.isLoadingPairDiff
        diffViewMode: plasmoid.configuration.diffViewMode || "compact"
        iconCache: root.iconCache
        metaCache: root.metaCache
        showPackageIcons: plasmoid.configuration.showPackageIcons
        iconStyle: root.iconStyle

        onViewModeChanged: mode => root.activeViewMode = mode
        onConfirmPending: () => root.confirmPendingAction()
        onCancelPending: () => root.cancelPendingAction()
        onCompareRequested: (a, b) => root.comparePair(a, b)
        onDiffViewModeChanged: mode => plasmoid.configuration.diffViewMode = mode
        onRefreshRequested: () => root.refreshGenerations()
        onCheckFlakeRequested: () => root.checkFlakeUpdates()
        onSelectGen: n => root.loadGenDetails(n)
        onCollapseGen: () => root.selectedGenNum = -1
        onRequestAction: (n, a) => root.requestAction(n, a)
        onDiffModeToggle: function (genNum) {
            root.diffMode = (root.diffMode === "booted" ? "prev" : "booted");
            const cache = Object.assign({}, root.detailsCache);
            delete cache[genNum];
            root.detailsCache = cache;
            root.loadGenDetails(genNum);
        }
        onFilterChanged: t => root.diffFilter = t
        onRunCommand: (cmd, label) => root.runCustomCommand(cmd, label)
        onCopyToClipboard: t => root.copyToClipboard(t)
        onDismissToast: function (idx) {
            var arr = root.toasts.slice();
            arr.splice(idx, 1);
            root.toasts = arr;
        }
        onHashRequested: (mode, input) => root.runHashProbe(mode, input)
        onPopOutRequested: root.pinned = !root.pinned
        onConfigureRequested: plasmoid.internalAction("configure").trigger()
        isPopOutOpen: root.pinned
    }
}
