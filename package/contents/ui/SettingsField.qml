pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as QQC
import QtQuick.Layouts

// Studio-style row: description on the left, one live control on the right.
Item {
    id: row
    required property var field
    required property var settings
    property bool first: false
    readonly property var value: settings[field.key]
    readonly property bool commands: field.key === "customCommands"
    readonly property bool colorField: field.type === "Color" || field.key === "bgColor"
    readonly property bool stacked: commands || (!field.choices && field.type === "String" && !colorField) || width < 460
    readonly property real controlWidth: field.type === "Bool" ? 44 : field.type === "Int" ? 130 : 210
    objectName: "setting_" + field.key
    implicitHeight: content.height + 28

    function commit(next) {
        settings[field.key] = next;
    }
    function commandList() {
        try {
            const list = JSON.parse(value || "[]");
            return Array.isArray(list) ? list : [];
        } catch (error) {
            return [];
        }
    }
    function editCommand(index, key, next) {
        const list = commandList();
        if (list[index][key] === next)
            return;
        list[index][key] = next;
        commit(JSON.stringify(list));
    }

    Rectangle {
        width: parent.width
        height: 1
        color: "#10ffffff"
        visible: !row.first
    }
    Item {
        id: content
        y: 14
        width: parent.width
        height: row.stacked ? heading.height + 10 + control.height : Math.max(heading.height, control.height)
        Column {
            id: heading
            width: row.stacked ? parent.width : parent.width - row.controlWidth - 20
            y: row.stacked ? 0 : (parent.height - height) / 2
            spacing: 4
            Text {
                width: parent.width
                text: row.field.label
                color: "#eeefeb"
                font.pixelSize: 12
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: row.field.help || ""
                color: "#9da3a5"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }
        Loader {
            id: control
            x: row.stacked ? 0 : parent.width - width
            y: row.stacked ? heading.height + 10 : (parent.height - height) / 2
            width: row.stacked ? parent.width : row.controlWidth
            height: (item as Item)?.implicitHeight ?? 0
            sourceComponent: row.commands ? commandsControl : row.field.choices ? choiceControl : row.field.type === "Bool" ? switchControl : row.field.type === "Int" ? numberControl : row.field.type === "Double" ? rangeControl : textControl
        }
    }
    Component {
        id: switchControl
        Item {
            implicitHeight: 26
            QQC.Switch {
                id: toggle
                anchors.right: parent.right
                width: 44
                height: 26
                padding: 0
                checked: !!row.value
                Accessible.name: row.field.label
                onToggled: row.commit(checked)
                indicator: Rectangle {
                    width: 40
                    height: 22
                    radius: 11
                    y: 2
                    color: toggle.checked ? "#91bcff" : "#3a3e40"
                    border.color: toggle.activeFocus ? "#ffffff" : "transparent"
                    Rectangle {
                        x: toggle.checked ? 21 : 3
                        y: 3
                        width: 16
                        height: 16
                        radius: 8
                        color: toggle.checked ? "#101b2c" : "#eeefeb"
                    }
                }
            }
        }
    }
    Component {
        id: choiceControl
        QQC.ComboBox {
            id: choice
            objectName: "choice_" + row.field.key
            implicitHeight: 34
            leftPadding: 10
            rightPadding: 30
            contentItem: Text {
                text: choice.displayText
                color: "#eeefeb"
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            indicator: Image {
                x: choice.width - width - 10
                y: (choice.height - height) / 2
                width: 12
                height: 12
                source: Qt.resolvedUrl("assets/ic_chevron_down.svg")
            }
            delegate: QQC.ItemDelegate {
                id: option
                required property int index
                required property var modelData
                width: choice.width - 8
                implicitHeight: 34
                highlighted: choice.highlightedIndex === index
                contentItem: Text {
                    text: option.modelData.label
                    color: option.highlighted ? "#c6dcff" : "#eeefeb"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 6
                    color: option.highlighted ? "#22344b" : option.hovered ? "#24282a" : "transparent"
                }
            }
            popup: QQC.Popup {
                y: choice.height + 4
                width: choice.width
                implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
                padding: 4
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: choice.popup.visible ? choice.delegateModel : null
                    currentIndex: choice.highlightedIndex
                    QQC.ScrollIndicator.vertical: QQC.ScrollIndicator {}
                }
                background: Rectangle {
                    color: "#151718"
                    radius: 8
                    border.color: "#3a3e40"
                }
            }
            background: Rectangle {
                radius: 8
                color: "#0f1112"
                border.color: choice.activeFocus ? "#91bcff" : "#1cffffff"
            }
            model: row.field.choices
            textRole: "label"
            valueRole: "value"
            currentIndex: model.findIndex(choice => choice.value === row.value)
            Accessible.name: row.field.label
            onActivated: row.commit(currentValue)
        }
    }
    Component {
        id: numberControl
        QQC.SpinBox {
            id: number
            background: Rectangle {
                radius: 8
                color: "#0f1112"
                border.color: number.activeFocus ? "#91bcff" : "#1cffffff"
            }
            editable: true
            from: row.field.min === undefined ? 0 : row.field.min
            to: row.field.max === undefined ? 100000 : row.field.max
            value: Number(row.value)
            Accessible.name: row.field.label
            onValueModified: row.commit(value)
        }
    }
    Component {
        id: rangeControl
        RowLayout {
            QQC.Slider {
                id: slider
                objectName: "slider_" + row.field.key
                Layout.fillWidth: true
                implicitHeight: 32
                background: Rectangle {
                    x: slider.leftPadding
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: slider.availableWidth
                    height: 4
                    radius: 2
                    color: "#3a3e40"
                    Rectangle {
                        x: slider.mirrored ? parent.width - width : 0
                        width: slider.position * parent.width
                        height: parent.height
                        radius: 2
                        color: "#91bcff"
                    }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 18
                    height: 18
                    radius: 9
                    color: slider.pressed ? "#c6dcff" : "#91bcff"
                    border.width: slider.activeFocus ? 2 : 1
                    border.color: slider.activeFocus ? "#eeefeb" : "#0f1112"
                }
                from: row.field.min || 0
                to: row.field.max || 2
                value: Number(row.value)
                stepSize: row.field.key === "fontScale" ? 0.05 : 1
                Accessible.name: row.field.label
                onMoved: row.commit(value)
            }
            Text {
                text: Number(row.value).toFixed(row.field.key === "fontScale" ? 2 : 0)
                color: "#eeefeb"
                font.pixelSize: 11
            }
        }
    }
    Component {
        id: textControl
        RowLayout {
            spacing: 8
            Rectangle {
                visible: row.colorField
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 6
                color: row.colorField ? String(row.value) : "transparent"
                border.color: "#44ffffff"
            }
            SettingsTextField {
                Layout.fillWidth: true
                text: String(row.value ?? "")
                selectByMouse: true
                Accessible.name: row.field.label
                font.pixelSize: 12
                onEditingFinished: {
                    if (row.colorField && !/^#(?:[a-fA-F0-9]{6}|[a-fA-F0-9]{8})$/.test(text)) {
                        text = String(row.value);
                        return;
                    }
                    row.commit(text);
                }
            }
        }
    }
    Component {
        id: commandsControl
        ColumnLayout {
            spacing: 10
            Repeater {
                model: row.commandList()
                ColumnLayout {
                    id: commandRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        SettingsTextField {
                            Layout.fillWidth: true
                            text: commandRow.modelData.label
                            placeholderText: qsTr("Button label")
                            Accessible.name: qsTr("Command label")
                            onEditingFinished: row.editCommand(commandRow.index, "label", text)
                        }
                        SettingsButton {
                            text: qsTr("Remove")
                            onClicked: {
                                const list = row.commandList();
                                list.splice(commandRow.index, 1);
                                row.commit(JSON.stringify(list));
                            }
                        }
                    }
                    SettingsTextField {
                        Layout.fillWidth: true
                        text: commandRow.modelData.cmd
                        placeholderText: qsTr("Command, e.g. upnix")
                        Accessible.name: qsTr("Command to run")
                        onEditingFinished: row.editCommand(commandRow.index, "cmd", text)
                    }
                }
            }
            SettingsButton {
                text: qsTr("Add command")
                enabled: row.commandList().length < 4
                onClicked: {
                    const list = row.commandList();
                    list.push({
                        label: "",
                        cmd: "",
                        color: "accent"
                    });
                    row.commit(JSON.stringify(list));
                }
            }
        }
    }
}
