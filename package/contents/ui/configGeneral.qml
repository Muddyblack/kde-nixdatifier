import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: root

    // ── General ─────────────────────────────────────────────────────────
    property alias cfg_flakePath: flakePathField.text
    property alias cfg_checkInterval: checkIntervalSpin.value
    property alias cfg_maxGenerations: maxGenerationsSpin.value
    property alias cfg_enableHostDetect: hostDetectCB.checked
    property alias cfg_defaultView: defaultViewHolder.value

    // ── Commands ────────────────────────────────────────────────────────
    property alias cfg_showCommandButtons: showCommandButtonsCB.checked
    property alias cfg_commandTerminal: commandTerminalField.text
    property string cfg_customCommands: ""

    // Internal list model — max 4 entries
    ListModel {
        id: cmdModel
    }

    function loadCmds() {
        cmdModel.clear();
        try {
            const arr = JSON.parse(cfg_customCommands || "[]");
            arr.slice(0, 4).forEach(function (e) {
                cmdModel.append({
                    label: e.label || "",
                    cmd: e.cmd || ""
                });
            });
        } catch (e) {}
    }

    function saveCmds() {
        const arr = [];
        for (let i = 0; i < cmdModel.count; i++) {
            const e = cmdModel.get(i);
            if (e.label || e.cmd)
                arr.push({
                    label: e.label,
                    cmd: e.cmd
                });
        }
        cfg_customCommands = JSON.stringify(arr);
    }

    Component.onCompleted: loadCmds()

    // ── Behavior ────────────────────────────────────────────────────────
    property alias cfg_usePkexec: usePkexecCB.checked
    property alias cfg_enableLiveSwitch: liveSwitchCB.checked
    property alias cfg_confirmBeforeRollback: confirmRollbackCB.checked
    property alias cfg_confirmBeforeDelete: confirmDeleteCB.checked
    property alias cfg_showDeleteButton: showDeleteCB.checked
    property alias cfg_showNotifications: showNotificationsCB.checked
    property alias cfg_autoRefreshOnOpen: autoRefreshCB.checked
    property alias cfg_showFlakeSection: showFlakeCB.checked
    property alias cfg_secretsPath: secretsPathField.text
    property alias cfg_secretsSourcePath: secretsSourcePathField.text
    property alias cfg_diffFilterEnabled: diffFilterCB.checked
    property alias cfg_showPackageIcons: showPackageIconsCB.checked
    property string cfg_diffViewMode: "compact"

    // ── Design ──────────────────────────────────────────────────────────
    property alias cfg_timelineColor: timelineColorButton.color
    property alias cfg_accentColor: accentColorButton.color
    property alias cfg_fontScale: fontScaleSlider.value
    property alias cfg_showBg: showBgCB.checked
    property string cfg_bgColor: "#800a0c14"
    property alias cfg_bgRadius: bgRadiusSlider.value
    property alias cfg_useSystemTextColor: useSystemTextColorCB.checked
    property alias cfg_customTextColor: customTextColorButton.color
    property alias cfg_enableGlow: enableGlowCB.checked
    property alias cfg_compactShowBadge: compactBadgeCB.checked
    property alias cfg_compactStyle: compactStyleHolder.value
    property alias cfg_iconStyle: iconStyleHolder.value

    Item {
        id: compactStyleHolder
        visible: false
        property string value: "icon"
    }
    Item {
        id: iconStyleHolder
        visible: false
        property string value: "colored"
    }
    Item {
        id: defaultViewHolder
        visible: false
        property string value: "timeline"
    }

    ColumnLayout {
        spacing: 0

        QQC.TabBar {
            id: tabBar
            Layout.fillWidth: true
            QQC.TabButton {
                text: i18n("General")
            }
            QQC.TabButton {
                text: i18n("Commands")
            }
            QQC.TabButton {
                text: i18n("Behavior")
            }
            QQC.TabButton {
                text: i18n("Design")
            }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: tabBar.currentIndex

            // ── Tab 0: General ────────────────────────────────────────
            QQC.ScrollView {
                clip: true
                contentWidth: availableWidth
                Kirigami.FormLayout {

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("NixOS & Flake")
                    }

                    QQC.TextField {
                        id: flakePathField
                        Kirigami.FormData.label: i18n("System Flake Path:")
                        placeholderText: i18n("e.g. /etc/nixos or ~/nixos-config (leave empty to auto-detect)")
                        Layout.fillWidth: true
                    }

                    QQC.Label {
                        text: i18n("Directory containing flake.nix. Leave empty and the widget will look in /etc/nixos, ~/nixos-config, ~/.config/nixos.")
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC.CheckBox {
                        id: hostDetectCB
                        Kirigami.FormData.label: i18n("Host detection:")
                        text: i18n("Detect current hostname and matching flake configuration")
                    }

                    QQC.SpinBox {
                        id: checkIntervalSpin
                        Kirigami.FormData.label: i18n("Check updates every (s):")
                        from: 60
                        to: 86400
                        stepSize: 300
                    }

                    QQC.SpinBox {
                        id: maxGenerationsSpin
                        Kirigami.FormData.label: i18n("Max generations shown:")
                        from: 3
                        to: 50
                        stepSize: 1
                    }

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Default View")
                    }

                    QQC.ComboBox {
                        id: defaultViewCombo
                        Kirigami.FormData.label: i18n("Open on:")
                        model: [
                            {
                                text: i18n("Timeline"),
                                value: "timeline"
                            },
                            {
                                text: i18n("Updates"),
                                value: "updates"
                            },
                            {
                                text: i18n("Secrets"),
                                value: "secrets"
                            }
                        ]
                        textRole: "text"
                        valueRole: "value"
                        currentIndex: {
                            for (var i = 0; i < model.length; i++)
                                if (model[i].value === cfg_defaultView)
                                    return i;
                            return 0;
                        }
                        onActivated: cfg_defaultView = model[currentIndex].value
                    }
                }
            }

            // ── Tab 1: Commands ───────────────────────────────────────
            QQC.ScrollView {
                clip: true
                contentWidth: availableWidth
                Kirigami.FormLayout {

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Quick-Run Commands")
                    }

                    QQC.CheckBox {
                        id: showCommandButtonsCB
                        Kirigami.FormData.label: i18n("Command pills:")
                        text: i18n("Show quick-run command buttons in header")
                    }

                    // Dynamic command rows (max 4)
                    ColumnLayout {
                        Kirigami.FormData.label: i18n("Buttons:")
                        Layout.fillWidth: true
                        spacing: 4
                        enabled: showCommandButtonsCB.checked
                        opacity: enabled ? 1.0 : 0.5

                        Repeater {
                            model: cmdModel
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                required property int index

                                QQC.TextField {
                                    placeholderText: i18n("Label")
                                    implicitWidth: 90
                                    text: model.label
                                    onTextChanged: {
                                        model.label = text;
                                        saveCmds();
                                    }
                                }
                                QQC.TextField {
                                    Layout.fillWidth: true
                                    placeholderText: i18n("Command (e.g. upnix)")
                                    text: model.cmd
                                    onTextChanged: {
                                        model.cmd = text;
                                        saveCmds();
                                    }
                                }
                                QQC.ToolButton {
                                    icon.name: "list-remove"
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    enabled: cmdModel.count > 1
                                    onClicked: {
                                        cmdModel.remove(index);
                                        saveCmds();
                                    }
                                    QQC.ToolTip.text: i18n("Remove")
                                    QQC.ToolTip.visible: hovered
                                    QQC.ToolTip.delay: 400
                                }
                            }
                        }

                        QQC.Button {
                            visible: cmdModel.count < 4
                            text: i18n("+ Add button")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            onClicked: {
                                cmdModel.append({
                                    label: "",
                                    cmd: ""
                                });
                                saveCmds();
                            }
                        }
                    }

                    QQC.TextField {
                        id: commandTerminalField
                        Kirigami.FormData.label: i18n("Terminal emulator:")
                        placeholderText: i18n("e.g. konsole, kitty, alacritty, foot")
                        Layout.fillWidth: true
                        enabled: showCommandButtonsCB.checked
                        opacity: enabled ? 1.0 : 0.5
                    }

                    QQC.Label {
                        text: i18n("Commands run from your flake path (or ~) in a new terminal. Supported: konsole, kitty, foot, alacritty, wezterm, xterm.")
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        enabled: showCommandButtonsCB.checked
                    }
                }
            }

            // ── Tab 2: Behavior ───────────────────────────────────────
            QQC.ScrollView {
                clip: true
                contentWidth: availableWidth
                Kirigami.FormLayout {

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Permissions")
                    }

                    QQC.CheckBox {
                        id: usePkexecCB
                        Kirigami.FormData.label: i18n("Authentication:")
                        text: i18n("Use pkexec for privileged operations (recommended)")
                    }

                    QQC.Label {
                        text: i18n("pkexec shows a polkit password prompt for switch or delete. Disable only if running as root or using sudo wrappers.")
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Switching Generations")
                    }

                    QQC.CheckBox {
                        id: liveSwitchCB
                        Kirigami.FormData.label: i18n("Live switch:")
                        text: i18n("Enable \"Activate Now\" (switch live without reboot)")
                    }

                    QQC.Label {
                        text: i18n("Activates the target generation immediately by restarting services. Riskier than \"Set Next Boot\" but doesn't require a reboot.")
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC.CheckBox {
                        id: confirmRollbackCB
                        Kirigami.FormData.label: i18n("Safety:")
                        text: i18n("Confirm before switching generation")
                    }

                    QQC.CheckBox {
                        id: confirmDeleteCB
                        text: i18n("Confirm before deleting generation")
                    }

                    QQC.CheckBox {
                        id: showDeleteCB
                        Kirigami.FormData.label: i18n("Deletion:")
                        text: i18n("Show delete generation button (use with care)")
                    }

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Updates & Detection")
                    }

                    QQC.CheckBox {
                        id: autoRefreshCB
                        Kirigami.FormData.label: i18n("Auto-refresh:")
                        text: i18n("Refresh generations list when widget opens")
                    }

                    QQC.CheckBox {
                        id: showFlakeCB
                        Kirigami.FormData.label: i18n("Flake updates:")
                        text: i18n("Probe flake inputs in the background")
                    }

                    QQC.TextField {
                        id: secretsPathField
                        Kirigami.FormData.label: i18n("Deployed secrets:")
                        placeholderText: i18n("Leave empty to auto-detect /run/secrets or /run/agenix.d")
                        Layout.fillWidth: true
                    }

                    QQC.Label {
                        text: i18n("Live decrypted secrets directory (agenix → /run/secrets, sops-nix → /run/secrets). Auto-detected when left empty.")
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC.TextField {
                        id: secretsSourcePathField
                        Kirigami.FormData.label: i18n("Source secrets file:")
                        placeholderText: i18n("Leave empty to auto-detect inside flake path")
                        Layout.fillWidth: true
                    }

                    QQC.Label {
                        text: i18n("Encrypted SOPS file in your flake repo. When empty, the widget scans the System Flake Path for the first file containing a sops: block (depth ≤ 4, skipping .git/.direnv/node_modules and *.example).")
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC.CheckBox {
                        id: showNotificationsCB
                        Kirigami.FormData.label: i18n("Notifications:")
                        text: i18n("Show desktop notification when flake updates are found")
                    }

                    QQC.CheckBox {
                        id: diffFilterCB
                        Kirigami.FormData.label: i18n("Package diff:")
                        text: i18n("Show search/filter field in package diff")
                    }

                    QQC.CheckBox {
                        id: showPackageIconsCB
                        text: i18n("Show per-package app icons in diff lists")
                    }
                }
            }

            // ── Tab 3: Design ─────────────────────────────────────────
            QQC.ScrollView {
                clip: true
                contentWidth: availableWidth
                Kirigami.FormLayout {

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Colors")
                    }

                    KQuickControls.ColorButton {
                        id: accentColorButton
                        Kirigami.FormData.label: i18n("Accent Color:")
                        showAlphaChannel: false
                    }

                    KQuickControls.ColorButton {
                        id: timelineColorButton
                        Kirigami.FormData.label: i18n("Timeline Color:")
                        showAlphaChannel: false
                    }

                    QQC.CheckBox {
                        id: useSystemTextColorCB
                        Kirigami.FormData.label: i18n("Text Color:")
                        text: i18n("Use system text color")
                    }

                    KQuickControls.ColorButton {
                        id: customTextColorButton
                        Kirigami.FormData.label: i18n("Custom Text Color:")
                        visible: !useSystemTextColorCB.checked
                        showAlphaChannel: false
                    }

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Typography")
                    }

                    RowLayout {
                        Kirigami.FormData.label: i18n("Font Scale:")
                        QQC.Slider {
                            id: fontScaleSlider
                            from: 0.7
                            to: 1.5
                            stepSize: 0.05
                            Layout.minimumWidth: 130
                        }
                        QQC.Label {
                            text: fontScaleSlider.value.toFixed(2) + "×"
                            Layout.minimumWidth: 40
                        }
                    }

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Glass Background")
                    }

                    QQC.CheckBox {
                        id: showBgCB
                        Kirigami.FormData.label: i18n("Background:")
                        text: i18n("Show glass background card")
                    }

                    KQuickControls.ColorButton {
                        id: bgColorButton
                        Kirigami.FormData.label: i18n("Background Color:")
                        visible: showBgCB.checked
                        showAlphaChannel: true
                        color: Qt.color(cfg_bgColor || "#800a0c14")
                        onColorChanged: cfg_bgColor = color.toString()
                    }

                    RowLayout {
                        visible: showBgCB.checked
                        Kirigami.FormData.label: i18n("Corner Radius:")
                        QQC.Slider {
                            id: bgRadiusSlider
                            from: 0.0
                            to: 30.0
                            stepSize: 1.0
                            Layout.minimumWidth: 130
                        }
                        QQC.Label {
                            text: bgRadiusSlider.value.toFixed(0) + "px"
                            Layout.minimumWidth: 40
                        }
                    }

                    QQC.CheckBox {
                        id: enableGlowCB
                        Kirigami.FormData.label: i18n("Effects:")
                        text: i18n("Soft glow on active nodes and accents")
                    }

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Panel Icon")
                    }

                    QQC.ComboBox {
                        id: compactStyleCombo
                        Kirigami.FormData.label: i18n("Icon Style:")
                        model: [
                            {
                                text: i18n("NixOS icon only"),
                                value: "icon"
                            },
                            {
                                text: i18n("Generation number only"),
                                value: "number"
                            },
                            {
                                text: i18n("Icon + generation"),
                                value: "both"
                            },
                            {
                                text: i18n("Glass pill"),
                                value: "pill"
                            }
                        ]
                        textRole: "text"
                        valueRole: "value"
                        currentIndex: {
                            for (var i = 0; i < model.length; i++)
                                if (model[i].value === cfg_compactStyle)
                                    return i;
                            return 0;
                        }
                        onActivated: cfg_compactStyle = model[currentIndex].value
                    }

                    QQC.ComboBox {
                        id: iconStyleCombo
                        Kirigami.FormData.label: i18n("Icon Color:")
                        model: [
                            {
                                text: i18n("Colored logo"),
                                value: "colored"
                            },
                            {
                                text: i18n("White logo"),
                                value: "white"
                            },
                            {
                                text: i18n("Black logo"),
                                value: "black"
                            },
                            {
                                text: i18n("Accent color logo"),
                                value: "accent"
                            }
                        ]
                        textRole: "text"
                        valueRole: "value"
                        currentIndex: {
                            for (var i = 0; i < model.length; i++)
                                if (model[i].value === cfg_iconStyle)
                                    return i;
                            return 0;
                        }
                        onActivated: cfg_iconStyle = model[currentIndex].value
                    }

                    QQC.CheckBox {
                        id: compactBadgeCB
                        Kirigami.FormData.label: i18n("Update Badge:")
                        text: i18n("Show pending update count badge on panel icon")
                    }
                }
            }
        }
    }
}
