import QtQuick
import QtQuick.Layouts

Item {
    id: configRoot
    implicitWidth: 620
    implicitHeight: 620
    Settings {
        id: state
    }
    property alias cfg_flakePath: state.flakePath
    property alias cfg_configRepoPath: state.configRepoPath
    property alias cfg_checkInterval: state.checkInterval
    property alias cfg_maxGenerations: state.maxGenerations
    property alias cfg_defaultView: state.defaultView
    property alias cfg_enableHostDetect: state.enableHostDetect
    property alias cfg_customCommands: state.customCommands
    property alias cfg_showCommandButtons: state.showCommandButtons
    property alias cfg_commandTerminal: state.commandTerminal
    property alias cfg_usePkexec: state.usePkexec
    property alias cfg_enableLiveSwitch: state.enableLiveSwitch
    property alias cfg_confirmBeforeRollback: state.confirmBeforeRollback
    property alias cfg_confirmBeforeDelete: state.confirmBeforeDelete
    property alias cfg_showDeleteButton: state.showDeleteButton
    property alias cfg_showNotifications: state.showNotifications
    property alias cfg_autoRefreshOnOpen: state.autoRefreshOnOpen
    property alias cfg_showFlakeSection: state.showFlakeSection
    property alias cfg_secretsPath: state.secretsPath
    property alias cfg_secretsSourcePath: state.secretsSourcePath
    property alias cfg_diffFilterEnabled: state.diffFilterEnabled
    property alias cfg_timelineColor: state.timelineColor
    property alias cfg_accentColor: state.accentColor
    property alias cfg_fontScale: state.fontScale
    property alias cfg_showBg: state.showBg
    property alias cfg_bgColor: state.bgColor
    property alias cfg_bgRadius: state.bgRadius
    property alias cfg_useSystemTextColor: state.useSystemTextColor
    property alias cfg_customTextColor: state.customTextColor
    property alias cfg_enableGlow: state.enableGlow
    property alias cfg_iconStyle: state.iconStyle
    property alias cfg_diffViewMode: state.diffViewMode
    property alias cfg_showPackageIcons: state.showPackageIcons
    property alias cfg_compactStyle: state.compactStyle
    property alias cfg_compactShowBadge: state.compactShowBadge
    property alias cfg_popupWidth: state.popupWidth
    property alias cfg_popupHeight: state.popupHeight
    property alias cfg_gcCustomCommand: state.gcCustomCommand
    property alias cfg_enableMotion: state.enableMotion
    SettingsEditor {
        anchors.fill: parent
        settings: state
    }
}
