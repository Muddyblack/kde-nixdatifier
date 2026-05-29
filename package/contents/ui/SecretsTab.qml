import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: secretsTab

    // ── Required properties ───────────────────────────────────────────────────
    required property color textColor
    required property real fs
    required property var deployedSecrets
    required property var sourceSecrets
    required property string activeViewMode

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }
    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * Kirigami.Theme.smallFont.pixelSize * fs));
    }

    anchors.fill: parent
    visible: activeViewMode === "secrets"

    readonly property bool nothingConfigured: deployedSecrets.path === "" && sourceSecrets.path === ""

    // helper: human-readable encryption label
    function encLabel(s) {
        if (!s.exists)
            return "";
        const k = s.encKind || "";
        const t = s.encType || "";
        if (k === "encrypted") {
            const tLabel = t === "age" ? "age" : t === "pgp" ? "PGP" : t === "mixed" ? "age+PGP" : t;
            return "SOPS" + (tLabel ? " / " + tLabel : "");
        }
        if (k === "plain")
            return i18n("Plaintext — not encrypted!");
        if (k === "directory")
            return i18n("Directory");
        return k;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Section header ────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Layout.bottomMargin: 8

            Kirigami.Icon {
                source: secretsTab.svg("ic_secrets")
                isMask: true
                implicitWidth: 20
                implicitHeight: 20
                color: secretsTab.deployedSecrets.exists || secretsTab.sourceSecrets.exists ? "#55cc55" : "#ff5555"
            }

            Text {
                text: i18n("SOPS / Agenix Secrets")
                color: secretsTab.textColor
                font.pixelSize: secretsTab.fpx(12)
                font.bold: true
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
            Layout.bottomMargin: 8
        }

        // scrollable body
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: secretsBody.implicitHeight
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: secretsBody
                width: parent.width
                spacing: 0

                // ── DEPLOYED block ────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Layout.bottomMargin: 10

                    // Sub-header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Layout.bottomMargin: 2

                        Text {
                            text: i18n("Deployed")
                            color: secretsTab.textColor
                            font.pixelSize: secretsTab.fpx(10)
                            font.bold: true
                            opacity: 0.7
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            radius: 3
                            color: secretsTab.deployedSecrets.exists ? Qt.rgba(0.2, 0.8, 0.3, 0.15) : Qt.rgba(1, 0.2, 0.2, 0.15)
                            border.color: secretsTab.deployedSecrets.exists ? "#55cc55" : "#ff5555"
                            border.width: 1
                            width: deployedPill.implicitWidth + 12
                            height: 17
                            Text {
                                id: deployedPill
                                anchors.centerIn: parent
                                text: secretsTab.deployedSecrets.exists ? i18n("OK") : i18n("Missing")
                                color: secretsTab.deployedSecrets.exists ? "#55cc55" : "#ff5555"
                                font.pixelSize: secretsTab.fpx(8)
                                font.bold: true
                            }
                        }
                    }

                    // rows
                    Repeater {
                        model: {
                            const d = secretsTab.deployedSecrets;
                            const rows = [];
                            rows.push({
                                label: i18n("Path:"),
                                value: d.path || i18n("Auto-detecting…"),
                                dim: !d.path
                            });
                            if (d.exists) {
                                rows.push({
                                    label: i18n("Last modified:"),
                                    value: d.lastModified || "—",
                                    dim: false
                                });
                                rows.push({
                                    label: i18n("Freshness:"),
                                    value: d.freshness || "—",
                                    dim: false,
                                    fresh: d.freshness
                                });
                                rows.push({
                                    label: i18n("Secrets:"),
                                    value: d.fileCount + (d.fileCount === 1 ? " " + i18n("file") : " " + i18n("files")),
                                    dim: false
                                });
                            }
                            return rows;
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: modelData.label
                                color: secretsTab.textColor
                                opacity: 0.42
                                font.pixelSize: secretsTab.fpx(9)
                                Layout.minimumWidth: 100
                            }
                            Text {
                                text: modelData.value
                                color: modelData.fresh === "fresh" ? "#55cc55" : modelData.fresh === "stale" ? "#ffaa44" : secretsTab.textColor
                                font.pixelSize: secretsTab.fpx(9)
                                opacity: modelData.dim ? 0.38 : 0.85
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Secret name chips (if any are listed)
                    Flow {
                        visible: secretsTab.deployedSecrets.exists && secretsTab.deployedSecrets.names.length > 0
                        Layout.fillWidth: true
                        spacing: 4
                        Layout.topMargin: 2

                        Repeater {
                            model: secretsTab.deployedSecrets.names
                            Rectangle {
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                                width: chipTxt.implicitWidth + 10
                                height: chipTxt.implicitHeight + 5
                                Text {
                                    id: chipTxt
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: secretsTab.textColor
                                    opacity: 0.7
                                    font.pixelSize: secretsTab.fpx(8)
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                            }
                        }
                    }
                }

                // ── Divider ───────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                    Layout.bottomMargin: 10
                    visible: secretsTab.sourceSecrets.path !== ""
                }

                // ── SOURCE block ──────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: secretsTab.sourceSecrets.path !== ""

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Layout.bottomMargin: 2

                        Text {
                            text: i18n("Source (encrypted)")
                            color: secretsTab.textColor
                            font.pixelSize: secretsTab.fpx(10)
                            font.bold: true
                            opacity: 0.7
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            radius: 3
                            color: secretsTab.sourceSecrets.exists ? Qt.rgba(0.2, 0.8, 0.3, 0.15) : Qt.rgba(1, 0.2, 0.2, 0.15)
                            border.color: secretsTab.sourceSecrets.exists ? "#55cc55" : "#ff5555"
                            border.width: 1
                            width: sourcePill.implicitWidth + 12
                            height: 17
                            Text {
                                id: sourcePill
                                anchors.centerIn: parent
                                text: secretsTab.sourceSecrets.exists ? i18n("OK") : i18n("Missing")
                                color: secretsTab.sourceSecrets.exists ? "#55cc55" : "#ff5555"
                                font.pixelSize: secretsTab.fpx(8)
                                font.bold: true
                            }
                        }
                    }

                    Repeater {
                        model: {
                            const s = secretsTab.sourceSecrets;
                            const rows = [];
                            rows.push({
                                label: i18n("Path:"),
                                value: s.path || i18n("Not configured"),
                                dim: !s.path,
                                warn: false
                            });
                            if (s.exists) {
                                rows.push({
                                    label: i18n("Last modified:"),
                                    value: s.lastModified || "—",
                                    dim: false,
                                    warn: false
                                });
                                const enc = secretsTab.encLabel(s);
                                rows.push({
                                    label: i18n("Format:"),
                                    value: enc || "—",
                                    dim: false,
                                    warn: s.encKind === "plain"
                                });
                                if (s.sopsVersion)
                                    rows.push({
                                        label: i18n("SOPS:"),
                                        value: "v" + s.sopsVersion,
                                        dim: false,
                                        warn: false
                                    });
                                if (s.recipientCount > 0)
                                    rows.push({
                                        label: i18n("Recipients:"),
                                        value: s.recipientCount + (s.encType ? " (" + s.encType + ")" : ""),
                                        dim: false,
                                        warn: false
                                    });
                            }
                            return rows;
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: modelData.label
                                color: secretsTab.textColor
                                opacity: 0.42
                                font.pixelSize: secretsTab.fpx(9)
                                Layout.minimumWidth: 100
                            }
                            Text {
                                text: modelData.value
                                color: modelData.warn ? "#ffaa44" : secretsTab.textColor
                                font.pixelSize: secretsTab.fpx(9)
                                opacity: modelData.dim ? 0.38 : 0.85
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Secret name chips
                    Flow {
                        visible: secretsTab.sourceSecrets.exists && secretsTab.sourceSecrets.names.length > 0
                        Layout.fillWidth: true
                        spacing: 4
                        Layout.topMargin: 2

                        Repeater {
                            model: secretsTab.sourceSecrets.names
                            Rectangle {
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                                width: srcChip.implicitWidth + 10
                                height: srcChip.implicitHeight + 5
                                Text {
                                    id: srcChip
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: secretsTab.textColor
                                    opacity: 0.7
                                    font.pixelSize: secretsTab.fpx(8)
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                }
                            }
                        }
                    }
                }

                // ── Nothing configured ────────────────────────────
                Text {
                    visible: secretsTab.nothingConfigured
                    text: i18n("No secrets found.\nDeployed secrets are auto-detected at /run/secrets or /run/agenix.d.\nSet a source file path in Settings → Behavior.")
                    color: secretsTab.textColor
                    opacity: 0.38
                    font.pixelSize: secretsTab.fpx(9)
                    wrapMode: Text.WordWrap
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }
}
