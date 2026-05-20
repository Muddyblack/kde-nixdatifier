import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: root

    property alias cfg_flakePath:             flakePathField.text
    property alias cfg_checkInterval:         checkIntervalSpin.value
    property alias cfg_maxGenerations:        maxGenerationsSpin.value

    property alias cfg_updateCommand:         updateCommandField.text
    property alias cfg_redeployCommand:       redeployCommandField.text
    property alias cfg_showCommandButtons:    showCommandButtonsCB.checked
    property alias cfg_commandTerminal:       commandTerminalField.text

    property alias cfg_usePkexec:             usePkexecCB.checked
    property alias cfg_confirmBeforeRollback: confirmRollbackCB.checked
    property alias cfg_showDeleteButton:      showDeleteCB.checked

    property alias cfg_showNotifications:     showNotificationsCB.checked
    property alias cfg_autoRefreshOnOpen:     autoRefreshCB.checked
    property alias cfg_showFlakeSection:      showFlakeCB.checked
    property alias cfg_diffFilterEnabled:     diffFilterCB.checked

    property alias cfg_timelineColor:         timelineColorButton.color
    property alias cfg_fontScale:             fontScaleSlider.value
    property alias cfg_showBg:               showBgCB.checked
    property alias cfg_bgColor:              bgColorButton.color
    property alias cfg_bgRadius:             bgRadiusSlider.value
    property alias cfg_useSystemTextColor:   useSystemTextColorCB.checked
    property alias cfg_customTextColor:      customTextColorButton.color
    property alias cfg_compactShowBadge:     compactBadgeCB.checked

    property alias cfg_compactStyle: compactStyleHolder.value

    Item {
        id: compactStyleHolder
        visible: false
        property string value: "icon"
    }

    ColumnLayout {
        spacing: 0

        QQC.TabBar {
            id: tabBar
            Layout.fillWidth: true
            QQC.TabButton { text: i18n("General") }
            QQC.TabButton { text: i18n("Appearance") }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: tabBar.currentIndex

            // ── Tab 0: General ────────────────────────────────────────────────
            Item {
                Kirigami.FormLayout {
                    anchors { left: parent.left; right: parent.right; top: parent.top }

                    // ── NixOS & Flake ─────────────────────────────────────────
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("NixOS & Flake")
                    }

                    QQC.TextField {
                        id: flakePathField
                        Kirigami.FormData.label: i18n("System Flake Path:")
                        placeholderText: i18n("e.g. /etc/nixos or /home/user/nixos-config")
                        Layout.fillWidth: true
                    }

                    QQC.Label {
                        text: i18n("Directory containing flake.nix and flake.lock. Leave empty to disable flake update checking.")
                        opacity: 0.55; font.pixelSize: 10; wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC.SpinBox {
                        id: checkIntervalSpin
                        Kirigami.FormData.label: i18n("Check updates every (s):")
                        from: 60; to: 86400; stepSize: 300
                    }

                    QQC.SpinBox {
                        id: maxGenerationsSpin
                        Kirigami.FormData.label: i18n("Max generations shown:")
                        from: 3; to: 50; stepSize: 1
                    }

                    // ── Custom Commands ───────────────────────────────────────
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Custom Commands")
                    }

                    QQC.CheckBox {
                        id: showCommandButtonsCB
                        Kirigami.FormData.label: i18n("Command buttons:")
                        text: i18n("Show quick-run command buttons in header")
                    }

                    QQC.TextField {
                        id: updateCommandField
                        Kirigami.FormData.label: i18n("Update command:")
                        placeholderText: i18n("e.g. update or sudo nixos-rebuild switch --flake .")
                        Layout.fillWidth: true
                        enabled: showCommandButtonsCB.checked
                        opacity: enabled ? 1.0 : 0.5
                    }

                    QQC.TextField {
                        id: redeployCommandField
                        Kirigami.FormData.label: i18n("Redeploy command:")
                        placeholderText: i18n("e.g. upnix or sudo nixos-rebuild switch")
                        Layout.fillWidth: true
                        enabled: showCommandButtonsCB.checked
                        opacity: enabled ? 1.0 : 0.5
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
                        text: i18n("Commands run in a terminal from your flake path (or ~). Supported: konsole, kitty, foot, alacritty, wezterm, xterm.")
                        opacity: 0.55; font.pixelSize: 10; wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        enabled: showCommandButtonsCB.checked
                    }

                    // ── Rollback / Auth ───────────────────────────────────────
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Rollback & Permissions")
                    }

                    QQC.CheckBox {
                        id: usePkexecCB
                        Kirigami.FormData.label: i18n("Authentication:")
                        text: i18n("Use pkexec for privileged operations (recommended)")
                    }

                    QQC.Label {
                        text: i18n("pkexec shows a polkit password prompt for rollback or delete. Disable only if running as root or using sudo wrappers.")
                        opacity: 0.55; font.pixelSize: 10; wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC.CheckBox {
                        id: confirmRollbackCB
                        Kirigami.FormData.label: i18n("Safety:")
                        text: i18n("Confirm before switching generation")
                    }

                    QQC.CheckBox {
                        id: showDeleteCB
                        Kirigami.FormData.label: i18n("Deletion:")
                        text: i18n("Show delete generation button (use with care)")
                    }

                    // ── Behaviour ─────────────────────────────────────────────
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Behaviour")
                    }

                    QQC.CheckBox {
                        id: autoRefreshCB
                        Kirigami.FormData.label: i18n("Auto-refresh:")
                        text: i18n("Refresh generations list when widget opens")
                    }

                    QQC.CheckBox {
                        id: showFlakeCB
                        Kirigami.FormData.label: i18n("Flake section:")
                        text: i18n("Show flake update status and notifications")
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
                }
            }

            // ── Tab 1: Appearance ─────────────────────────────────────────────
            Item {
                Kirigami.FormLayout {
                    anchors { left: parent.left; right: parent.right; top: parent.top }

                    // ── Colors & Typography ───────────────────────────────────
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Colors & Typography")
                    }

                    KQuickControls.ColorButton {
                        id: timelineColorButton
                        Kirigami.FormData.label: i18n("Timeline Color:")
                        showAlphaChannel: false
                    }

                    RowLayout {
                        Kirigami.FormData.label: i18n("Font Scale:")
                        QQC.Slider {
                            id: fontScaleSlider
                            from: 0.7; to: 1.5; stepSize: 0.05
                            Layout.minimumWidth: 130
                        }
                        QQC.Label { text: fontScaleSlider.value.toFixed(2) + "×"; Layout.minimumWidth: 40 }
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

                    // ── Background Card ───────────────────────────────────────
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Background Card")
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
                    }

                    RowLayout {
                        visible: showBgCB.checked
                        Kirigami.FormData.label: i18n("Corner Radius:")
                        QQC.Slider {
                            id: bgRadiusSlider
                            from: 0.0; to: 30.0; stepSize: 1.0
                            Layout.minimumWidth: 130
                        }
                        QQC.Label { text: bgRadiusSlider.value.toFixed(0) + "px"; Layout.minimumWidth: 40 }
                    }

                    // ── Panel / Compact Icon ──────────────────────────────────
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Panel / Compact Icon")
                    }

                    QQC.ComboBox {
                        id: compactStyleCombo
                        Kirigami.FormData.label: i18n("Icon Style:")
                        model: [
                            { text: i18n("NixOS icon only"),          value: "icon"   },
                            { text: i18n("Active generation number"),  value: "number" },
                            { text: i18n("Icon + generation number"),  value: "both"   }
                        ]
                        textRole: "text"
                        valueRole: "value"
                        currentIndex: {
                            for (var i = 0; i < model.length; i++)
                                if (model[i].value === cfg_compactStyle) return i
                            return 0
                        }
                        onActivated: cfg_compactStyle = model[currentIndex].value
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
