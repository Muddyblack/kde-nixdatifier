import QtQuick

FullView {
    implicitWidth: engine.settings.popupWidth || 600
    implicitHeight: engine.settings.popupHeight || 740
    required property var engine
    storePathCache: engine.storePathCache
    generationCounts: engine.generationCounts
    onGenerationCountsRequested: genNum => {
        if (engine.autoStart)
            engine.requestGenerationCounts(genNum);
    }
    onStorePathRequested: pkg => engine.resolveStorePath(pkg)
    updatingInput: engine.updatingInput
    isSpinning: engine.isSpinning
    busyLabel: engine.busyLabel
    enableGlow: engine.settings.enableGlow
    enableMotion: engine.settings.enableMotion !== false
    enableLiveSwitch: engine.settings.enableLiveSwitch

    uiActive: engine.uiActive
    accentColor: engine.accentColor
    timelineColor: engine.timelineColor
    textColor: engine.textColor
    fs: engine.fs
    showBg: engine.settings.showBg
    bgColor: Qt.color(engine.settings.bgColor || "#800a0c14")
    bgRadius: engine.settings.bgRadius
    isBusy: engine.isBusy
    isLoadingGens: engine.isLoadingGens
    isLoadingDetails: engine.isLoadingDetails
    isCheckingFlake: engine.isCheckingFlake
    generations: engine.generations
    flakeUpdates: engine.flakeUpdates
    toasts: engine.toasts
    lastFlakeCheckTime: engine.lastFlakeCheckTime
    activeGenNum: engine.activeGenNum
    bootedGenNum: engine.bootedGenNum
    selectedGenNum: engine.selectedGenNum
    detailsCache: engine.detailsCache
    diffFilter: engine.diffFilter
    diffMode: engine.diffMode
    showDeleteButton: engine.settings.showDeleteButton
    diffFilterEnabled: engine.settings.diffFilterEnabled
    showFlakeSection: engine.settings.showFlakeSection
    showCommandButtons: engine.settings.showCommandButtons
    customCommands: engine.customCommands
    actionType: engine.currentActionType
    actionGenNum: engine.currentActionGenNum
    activeViewMode: engine.activeViewMode
    sopsStatus: engine.sopsStatus
    deployedSecrets: engine.deployedSecrets
    sourceSecrets: engine.sourceSecrets
    hostname: engine.hostname
    nixosVersion: engine.nixosVersion
    lastActivationTime: engine.lastActivationTime
    uptime: engine.uptime
    diskStoreBytes: engine.diskStoreBytes
    diskReclaimableBytes: engine.diskReclaimableBytes
    diskFreeBytes: engine.diskFreeBytes
    hashResult: engine.hashResult
    isProbingHash: engine.isProbingHash
    pendingGenNum: engine.pendingGenNum
    pendingAction: engine.pendingAction
    pendingCleanup: engine.pendingCleanup
    gcCustomCommand: engine.settings.gcCustomCommand || ""
    usePkexec: engine.settings.usePkexec
    pairDiffCache: engine.pairDiffCache
    isLoadingPairDiff: engine.isLoadingPairDiff
    configDiffCache: engine.configDiffCache
    dryRunCache: engine.dryRunCache
    isDryRunning: engine.isDryRunning
    diffViewMode: engine.settings.diffViewMode || "compact"
    iconCache: engine.iconCache
    metaCache: engine.metaCache
    showPackageIcons: engine.settings.showPackageIcons
    iconStyle: engine.iconStyle

    onViewModeChanged: mode => engine.activeViewMode = mode
    onConfirmPending: () => engine.confirmPendingAction()
    onCancelPending: () => engine.cancelPendingAction()
    onCleanupVariantPicked: mode => {
        engine.pendingCleanup = mode;
    }
    onConfirmCleanup: mode => {
        engine.pendingCleanup = "";
        engine.executeCleanup(mode);
    }
    onCancelCleanup: () => {
        engine.pendingCleanup = "";
    }
    onCompareRequested: (a, b) => engine.comparePair(a, b)
    onDiffViewModeChanged: engine.settings.diffViewMode = diffViewMode
    onRefreshRequested: () => engine.refreshGenerations()
    onCheckFlakeRequested: () => engine.checkFlakeUpdates()
    onSelectGen: n => engine.loadGenDetails(n)
    onCollapseGen: () => engine.selectedGenNum = -1
    onRequestAction: (n, a) => engine.requestAction(n, a)
    onDiffModeToggle: function (genNum) {
        engine.diffMode = (engine.diffMode === "booted" ? "prev" : "booted");
        const cache = Object.assign({}, engine.detailsCache);
        delete cache[genNum];
        engine.detailsCache = cache;
        engine.loadGenDetails(genNum);
    }
    onFilterChanged: t => engine.diffFilter = t
    onRunCommand: (cmd, label) => engine.runCustomCommand(cmd, label)
    onCopyToClipboard: t => engine.copyToClipboard(t)
    onDismissToast: function (idx) {
        var arr = engine.toasts.slice();
        arr.splice(idx, 1);
        engine.toasts = arr;
    }
    onHashRequested: (mode, input) => engine.runHashProbe(mode, input)
    onDryRunRequested: (inputName, overrideRef) => engine.runDryPreview(inputName, overrideRef)
    onUpdateInputRequested: inputName => engine.runFlakeUpdateInput(inputName)
    onPopOutRequested: engine.pinned = !engine.pinned
    onConfigureRequested: engine.configureRequested()
    isPopOutOpen: engine.pinned
}
