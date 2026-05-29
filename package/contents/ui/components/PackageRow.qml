import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

// Single expandable package diff row.
// Used in both GenerationDelegate (timeline) and the Diff tab.
Item {
    id: root

    property var pkg: ({})     // { name, type, oldVersion, newVersion, size }
    property color accentColor: "transparent"
    property color textColor: "white"
    property real fs: 1.0

    // When true the detail panel is always open (detailed mode);
    // when false the user toggles it by clicking the row (compact mode).
    property bool forceExpanded: false
    property var iconCache: ({})
    property var metaCache: ({})
    property bool showPackageIcons: true

    signal copyRequested(string text)

    // Theme-aware font sizing. Legacy hardcoded sizes were tuned against a 9px base.
    readonly property int baseFontPx: Kirigami.Theme.smallFont.pixelSize
    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * baseFontPx * fs));
    }

    readonly property string resolvedIcon: {
        if (!showPackageIcons || !pkgName)
            return "";
        const ic = iconCache[pkgName];
        return (ic !== undefined && ic !== "") ? ic : "";
    }

    // ── Internal ──────────────────────────────────────────────────────────────
    property bool _userExpanded: false
    readonly property bool isOpen: forceExpanded || _userExpanded

    // Safe accessors — guard against the brief window where pkg is ({})
    readonly property string pkgName: pkg ? (pkg.name || "") : ""
    readonly property string pkgType: pkg ? (pkg.type || "") : ""
    readonly property string pkgOldVersion: pkg ? (pkg.oldVersion || "") : ""
    readonly property string pkgNewVersion: pkg ? (pkg.newVersion || "") : ""
    readonly property string pkgSize: pkg ? (pkg.size || "").replace(/KiB/g, "KB").replace(/MiB/g, "MB").replace(/GiB/g, "GB") : ""

    function svg(name) {
        return Qt.resolvedUrl("../assets/" + name + ".svg");
    }

    property color sigil: pkg && pkg.type === "added" ? "#3ddc84" : pkg && pkg.type === "removed" ? "#ff6b6b" : "#ffb74d"

    height: isOpen ? 22 + detailPanel.implicitHeight + 6 : 22
    Behavior on height {
        NumberAnimation {
            duration: 170
            easing.type: Easing.InOutQuad
        }
    }

    // ── Compact row ───────────────────────────────────────────────────────────
    Rectangle {
        id: rowBg
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 22
        radius: 3
        color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 80
            }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 5
                rightMargin: 5
            }
            spacing: 5

            // Sigil +/−/~
            Text {
                text: root.pkgType === "added" ? "+" : (root.pkgType === "removed" ? "−" : "~")
                color: root.sigil
                font.pixelSize: root.fpx(11)
                font.bold: true
                Layout.minimumWidth: 12
            }

            // Package icon — system app icon when available, generic fallback
            Kirigami.Icon {
                readonly property bool hasAppIcon: root.showPackageIcons && root.resolvedIcon !== ""
                source: hasAppIcon ? root.resolvedIcon : root.svg("ic_package_added")
                implicitWidth: hasAppIcon ? 16 : 12
                implicitHeight: hasAppIcon ? 16 : 12
                isMask: !hasAppIcon
                color: hasAppIcon ? "transparent" : root.sigil
                opacity: hasAppIcon ? 1.0 : 0.65
                smooth: true
            }

            // Name
            Text {
                text: root.pkgName
                color: root.textColor
                font.pixelSize: root.fpx(9)
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Version
            Text {
                text: root.pkgType === "added" ? root.pkgNewVersion : root.pkgType === "removed" ? root.pkgOldVersion : root.pkgOldVersion + " → " + root.pkgNewVersion
                color: root.textColor
                opacity: 0.55
                font.pixelSize: root.fpx(8)
                font.family: Kirigami.Theme.fixedWidthFont.family
                elide: Text.ElideRight
                Layout.preferredWidth: 155
                Layout.maximumWidth: 175
                horizontalAlignment: Text.AlignRight
            }

            // Size delta
            Text {
                visible: root.pkgSize !== ""
                text: root.pkgSize
                color: root.sigil
                opacity: 0.80
                font.pixelSize: root.fpx(7.5)
                font.family: Kirigami.Theme.fixedWidthFont.family
                Layout.preferredWidth: 62
                Layout.maximumWidth: 72
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            // Chevron (only in compact mode)
            Kirigami.Icon {
                visible: !root.forceExpanded
                source: root.isOpen ? root.svg("ic_chevron_up") : root.svg("ic_chevron_down")
                implicitWidth: 11
                implicitHeight: 11
                isMask: true
                color: root.textColor
                opacity: rowMa.containsMouse ? 0.65 : 0.20
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root.forceExpanded
            onClicked: root._userExpanded = !root._userExpanded
        }
    }

    // ── Detail panel ──────────────────────────────────────────────────────────
    Rectangle {
        id: detailPanel
        anchors {
            left: parent.left
            right: parent.right
            top: rowBg.bottom
            topMargin: 2
            leftMargin: 18
        }
        visible: root.isOpen
        implicitHeight: detailCol.implicitHeight + 12
        radius: 5
        color: Qt.rgba(root.sigil.r, root.sigil.g, root.sigil.b, 0.06)
        border.width: 0

        ColumnLayout {
            id: detailCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 5

            // Version row — upgrade
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgType !== "added" && root.pkgType !== "removed" && root.pkgOldVersion !== "" && root.pkgNewVersion !== ""
                Text {
                    text: i18n("Version")
                    color: root.textColor
                    opacity: 0.38
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgOldVersion + "  →  " + root.pkgNewVersion
                    color: root.textColor
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Version row — added
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgType === "added" && root.pkgNewVersion !== ""
                Text {
                    text: i18n("Version")
                    color: root.textColor
                    opacity: 0.38
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgNewVersion
                    color: root.sigil
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    font.bold: true
                }
            }

            // Version row — removed
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgType === "removed" && root.pkgOldVersion !== ""
                Text {
                    text: i18n("Version")
                    color: root.textColor
                    opacity: 0.38
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgOldVersion
                    color: root.sigil
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    font.bold: true
                }
            }

            // Size delta
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgSize !== ""
                Text {
                    text: i18n("Size delta")
                    color: root.textColor
                    opacity: 0.38
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgSize
                    color: root.sigil
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    font.bold: true
                }
            }

            // Store path + copy
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: i18n("Store path")
                    color: root.textColor
                    opacity: 0.38
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    id: storePath
                    readonly property string ver: root.pkgType === "removed" ? root.pkgOldVersion : root.pkgNewVersion
                    text: "/nix/store/…-" + root.pkgName + "-" + ver
                    color: root.textColor
                    opacity: 0.60
                    font.pixelSize: root.fpx(7.5)
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 20
                    height: 17
                    radius: 4
                    color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: root.svg("ic_copy")
                        implicitWidth: 10
                        implicitHeight: 10
                        isMask: true
                        color: root.textColor
                        opacity: 0.60
                    }
                    MouseArea {
                        id: copyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyRequested(storePath.text)
                        ToolTip.text: i18n("Copy store path")
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }
            }

            // Upstream / source link.
            // Prefers (in order):
            //   1) meta.homepage from nixpkgs  → real upstream project page
            //   2) Website from a plasmoid metadata.json → user-built widget repo
            //   3) nixpkgs search fallback     → at least lets the user find the derivation
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                readonly property var metaEntry: root.metaCache && root.pkgName ? root.metaCache[root.pkgName] : undefined
                // The URL ultimately comes from either nixpkgs meta.homepage or a
                // plasmoid metadata.json's Website field — both are upstream-controlled
                // strings. Restrict to http(s) so a malicious entry can't open
                // file:// / javascript: / data: / etc. via Qt.openUrlExternally.
                readonly property string rawUrl: metaEntry && metaEntry.url ? metaEntry.url : ""
                readonly property string metaUrl: /^https?:\/\//i.test(rawUrl) ? rawUrl : ""
                readonly property string metaSource: metaUrl !== "" && metaEntry && metaEntry.source ? metaEntry.source : ""
                readonly property string searchUrl: "https://github.com/NixOS/nixpkgs/search?q=" + encodeURIComponent(root.pkgName)
                readonly property string activeUrl: metaUrl !== "" ? metaUrl : searchUrl

                // Short label that hints at the link's origin
                readonly property string label: {
                    if (metaSource === "plasmoid")
                        return i18n("upstream");
                    if (metaSource === "nixpkgs")
                        return i18n("homepage");
                    return "nixpkgs";
                }

                // Pretty-printed host + path for the link text
                readonly property string displayUrl: {
                    const u = activeUrl;
                    const stripped = u.replace(/^https?:\/\//, "").replace(/\/$/, "");
                    return stripped.length > 48 ? stripped.substring(0, 45) + "…" : stripped;
                }

                Text {
                    text: parent.label
                    color: root.textColor
                    opacity: 0.38
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: parent.displayUrl + "  ↗"
                    color: root.accentColor
                    opacity: ghMa.containsMouse ? 1.0 : 0.72
                    font.pixelSize: root.fpx(8)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                    MouseArea {
                        id: ghMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(parent.parent.activeUrl)
                        ToolTip.text: parent.parent.activeUrl
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }
            }
        }
    }
}
