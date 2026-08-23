import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: hashTab

    // ── Required properties ───────────────────────────────────────────────────
    // See FullView.uiActive — false while the popup is closed.
    property bool uiActive: true
    required property color accentColor
    required property color textColor
    required property real fs
    required property string iconStyle
    required property var hashResult
    required property string activeViewMode
    property bool isProbingHash: false

    function fpx(n) {
        return Math.max(1, Math.round(n / 9.0 * Kirigami.Theme.smallFont.pixelSize * fs));
    }

    signal hashRequested(string mode, string input)
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "hash"

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── Mode selector ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    {
                        id: "url",
                        label: i18n("URL"),
                        tip: i18n("sha256 of a remote file (fetchurl)")
                    },
                    {
                        id: "zip",
                        label: i18n("Zip/Tar"),
                        tip: i18n("sha256 of an unpacked archive (fetchzip)")
                    },
                    {
                        id: "github",
                        label: i18n("GitHub"),
                        tip: i18n("owner/repo/rev → sha256 (fetchFromGitHub)")
                    },
                    {
                        id: "file",
                        label: i18n("File"),
                        tip: i18n("sha256sum of a local file")
                    },
                    {
                        id: "store",
                        label: i18n("Store"),
                        tip: i18n("NAR hash of a /nix/store/... path")
                    }
                ]

                Rectangle {
                    readonly property bool active: hashModeHolder.value === modelData.id
                    radius: 4
                    height: 24
                    width: modeLbl.implicitWidth + 14
                    color: active ? Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.22) : (modeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03))
                    border.color: active ? Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.5) : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }
                    }

                    Text {
                        id: modeLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        color: active ? hashTab.accentColor : Qt.rgba(hashTab.textColor.r, hashTab.textColor.g, hashTab.textColor.b, 0.65)
                        font.pixelSize: hashTab.fpx(9)
                        font.bold: active
                    }

                    ToolTip.text: modelData.tip
                    ToolTip.visible: modeMa.containsMouse
                    ToolTip.delay: 500

                    MouseArea {
                        id: modeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            hashModeHolder.value = modelData.id;
                            hashInputField.text = "";
                            hashResultField.text = "";
                            hashResultField.isError = false;
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Hidden mode holder (no visual, just state)
        Item {
            id: hashModeHolder
            visible: false
            property string value: "url"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Placeholder hint ──────────────────────────────────────
        Text {
            Layout.fillWidth: true
            text: {
                switch (hashModeHolder.value) {
                case "url":
                    return i18n("https://example.com/file.tar.gz");
                case "zip":
                    return i18n("https://example.com/archive.zip");
                case "github":
                    return i18n("owner/repo/v1.2.3   or   owner/repo/abc1234");
                case "file":
                    return i18n("/path/to/local/file");
                case "store":
                    return i18n("/nix/store/abc123...-some-package");
                default:
                    return "";
                }
            }
            color: hashTab.textColor
            opacity: 0.35
            font.pixelSize: hashTab.fpx(8)
            font.italic: true
            wrapMode: Text.Wrap
        }

        // ── Input field ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: hashInputField
                Layout.fillWidth: true
                implicitHeight: 28
                font.pixelSize: hashTab.fpx(9)
                font.family: Kirigami.Theme.fixedWidthFont.family
                placeholderText: i18n("Enter input…")
                leftPadding: 8
                rightPadding: 8
                color: hashTab.textColor
                onAccepted: hashRunButton.clicked()
                background: Rectangle {
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: hashInputField.activeFocus ? Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.6) : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }
            }

            Button {
                id: hashRunButton
                text: hashSpinner.visible ? "" : i18n("Get Hash")
                implicitHeight: 28
                enabled: hashInputField.text.trim() !== "" && !hashTab.isProbingHash
                font.pixelSize: hashTab.fpx(9)
                font.bold: true

                onClicked: {
                    hashResultField.text = "";
                    hashResultField.isError = false;
                    hashTab.hashRequested(hashModeHolder.value, hashInputField.text.trim());
                }

                background: Rectangle {
                    radius: 4
                    color: parent.enabled ? (parent.hovered ? Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.30) : Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.16)) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: parent.enabled ? hashTab.accentColor : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                }
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Kirigami.Icon {
                        id: hashSpinner
                        source: Qt.resolvedUrl("nixos-logo.svg")
                        isMask: hashTab.iconStyle !== "colored"
                        color: {
                            if (hashTab.iconStyle === "white")
                                return "#ffffff";
                            if (hashTab.iconStyle === "black")
                                return "#000000";
                            return hashTab.accentColor;
                        }
                        visible: hashTab.isProbingHash
                        implicitWidth: 14
                        implicitHeight: 14
                        RotationAnimation on rotation {
                            running: hashSpinner.visible && hashTab.uiActive
                            from: 0
                            to: 360
                            duration: 1200
                            loops: Animation.Infinite
                        }
                    }
                    Text {
                        visible: !hashSpinner.visible
                        text: hashRunButton.text
                        color: hashRunButton.enabled ? hashTab.textColor : Qt.rgba(hashTab.textColor.r, hashTab.textColor.g, hashTab.textColor.b, 0.4)
                        font: hashRunButton.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // ── Result field ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: hashResultField.text !== "" ? hashResultRow.implicitHeight + 16 : 0
            clip: true
            radius: 5
            color: hashResultField.isError ? Qt.rgba(1, 0.2, 0.2, 0.12) : Qt.rgba(0.2, 0.85, 0.2, 0.09)
            border.color: hashResultField.isError ? "#ff5555" : "#55cc55"
            border.width: 1
            Behavior on height {
                NumberAnimation {
                    duration: 180
                }
            }
            visible: height > 0

            RowLayout {
                id: hashResultRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 6

                TextEdit {
                    id: hashResultField
                    property bool isError: false
                    Layout.fillWidth: true
                    readOnly: true
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: hashTab.fpx(9)
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    color: isError ? "#ff7777" : "#88ff88"
                    selectByMouse: true
                    // Make selection visible
                    selectionColor: Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.35)
                }

                ToolButton {
                    visible: !hashResultField.isError && hashResultField.text !== ""
                    icon.name: "edit-copy"
                    implicitWidth: 22
                    implicitHeight: 22
                    ToolTip.text: i18n("Copy hash")
                    ToolTip.visible: hovered
                    ToolTip.delay: 400
                    onClicked: hashTab.copyToClipboard(hashResultField.text)
                }
            }
        }

        // ── SRI format toggle + formatted output ──────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: hashResultField.text !== "" && !hashResultField.isError && !hashResultField.text.startsWith("sha256:") && !hashResultField.text.startsWith("sha256-")
            spacing: 8

            Text {
                text: i18n("As SRI:")
                color: hashTab.textColor
                opacity: 0.5
                font.pixelSize: hashTab.fpx(8)
            }

            TextEdit {
                id: sriField
                readOnly: true
                selectByMouse: true
                text: hashResultField.text !== "" && !hashResultField.isError ? "sha256-" + Qt.btoa(hashResultField.text.replace(/([0-9a-f]{2})/gi, (m, h) => String.fromCharCode(parseInt(h, 16)))) : ""
                font.pixelSize: hashTab.fpx(8)
                font.family: Kirigami.Theme.fixedWidthFont.family
                color: Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.85)
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere
                selectionColor: Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.35)
            }

            ToolButton {
                icon.name: "edit-copy"
                implicitWidth: 22
                implicitHeight: 22
                ToolTip.text: i18n("Copy SRI hash")
                ToolTip.visible: hovered
                ToolTip.delay: 400
                onClicked: hashTab.copyToClipboard(sriField.text)
            }
        }

        // ── Nix snippet ───────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: hashResultField.text !== "" && !hashResultField.isError

            Text {
                text: i18n("Nix snippet:")
                color: hashTab.textColor
                opacity: 0.45
                font.pixelSize: hashTab.fpx(8)
            }

            Rectangle {
                Layout.fillWidth: true
                height: snippetEdit.implicitHeight + 12
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 6
                    }
                    spacing: 6

                    TextEdit {
                        id: snippetEdit
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: hashTab.fpx(8)
                        font.family: Kirigami.Theme.fixedWidthFont.family
                        color: hashTab.textColor
                        opacity: 0.85
                        selectionColor: Qt.rgba(hashTab.accentColor.r, hashTab.accentColor.g, hashTab.accentColor.b, 0.35)

                        text: {
                            if (hashResultField.text === "" || hashResultField.isError)
                                return "";
                            const h = hashResultField.text;
                            const input = hashInputField.text.trim();
                            switch (hashModeHolder.value) {
                            case "url":
                                return 'fetchurl {\n  url = "' + input + '";\n  sha256 = "' + h + '";\n}';
                            case "zip":
                                return 'fetchzip {\n  url = "' + input + '";\n  sha256 = "' + h + '";\n}';
                            case "github":
                                {
                                    const parts = input.split("/");
                                    return 'fetchFromGitHub {\n  owner = "' + (parts[0] || "") + '";\n  repo  = "' + (parts[1] || "") + '";\n  rev   = "' + (parts.slice(2).join("/") || "") + '";\n  sha256 = "' + h + '";\n}';
                                }
                            case "file":
                            case "store":
                                return '# sha256: ' + h;
                            default:
                                return h;
                            }
                        }
                    }

                    ToolButton {
                        icon.name: "edit-copy"
                        implicitWidth: 22
                        implicitHeight: 22
                        Layout.alignment: Qt.AlignTop
                        ToolTip.text: i18n("Copy snippet")
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        onClicked: hashTab.copyToClipboard(snippetEdit.text)
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Text {
            text: i18n("nix-prefetch-url must be available on PATH. GitHub mode fetches the archive tarball.")
            color: hashTab.textColor
            opacity: 0.28
            font.pixelSize: hashTab.fpx(8)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // React to hashResult pushed back from main
    onHashResultChanged: {
        const r = hashTab.hashResult;
        if (r === null)
            return;
        hashSpinner.visible = false;
        hashResultField.isError = r.isError;
        hashResultField.text = r.value;
    }
}
