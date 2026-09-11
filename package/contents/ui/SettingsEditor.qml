import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SettingsSchema.js" as Schema
import "shared" as UI

Pane {
    id: editor
    padding: 0
    background: null
    palette.window: "#131923"
    palette.windowText: UI.Theme.textColor
    palette.base: "#1c2533"
    palette.text: UI.Theme.textColor
    palette.button: "#242f40"
    palette.buttonText: UI.Theme.textColor
    palette.highlight: UI.Theme.highlightColor
    palette.highlightedText: "#131923"
    palette.placeholderText: UI.Theme.muted
    required property var settings
    property bool hyprland: false
    property int currentTab: 0
    readonly property var tabs: [qsTr("General"), qsTr("Commands"), qsTr("Behavior"), qsTr("Design")]
    readonly property var tabKeys: ["General", "Commands", "Behavior", "Design"]
    function setValue(key, value) {
        settings[key] = value;
    }
    function commandArray() {
        try {
            return JSON.parse(settings.customCommands || "[]");
        } catch (e) {
            return [];
        }
    }
    function changeCommand(index, key, value) {
        const list = commandArray();
        list[index][key] = value;
        settings.customCommands = JSON.stringify(list);
    }
    contentItem: ColumnLayout {
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: editor.tabs
                UI.ActionButton {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    text: modelData
                    primary: editor.currentTab === index
                    onClicked: editor.currentTab = index
                }
            }
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 13
                Repeater {
                    model: Schema.fields.filter(f => f.tab === editor.tabKeys[editor.currentTab])
                    ColumnLayout {
                        id: field
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 6
                        readonly property var value: editor.settings[modelData.key]
                        readonly property bool groupStart: index === 0 || Schema.fields.filter(f => f.tab === editor.tabKeys[editor.currentTab])[index - 1].group !== modelData.group
                        Text {
                            visible: field.groupStart
                            Layout.topMargin: field.index ? 12 : 0
                            text: field.modelData.group
                            color: UI.Theme.highlightColor
                            font: UI.Theme.defaultFont
                        }
                        CheckBox {
                            visible: field.modelData.type === "Bool"
                            Layout.fillWidth: true
                            text: field.modelData.label
                            checked: !!field.value
                            onToggled: editor.setValue(field.modelData.key, checked)
                        }
                        Text {
                            visible: field.modelData.type !== "Bool"
                            text: field.modelData.label
                            color: UI.Theme.textColor
                            font: UI.Theme.smallFont
                        }
                        TextField {
                            visible: !field.modelData.choices && (field.modelData.type === "String" || field.modelData.type === "Color") && field.modelData.key !== "customCommands"
                            Layout.fillWidth: true
                            text: String(field.value)
                            selectByMouse: true
                            onEditingFinished: {
                                if ((field.modelData.type === "Color" || field.modelData.key === "bgColor") && !/^#(?:[a-fA-F0-9]{6}|[a-fA-F0-9]{8})$/.test(text)) {
                                    text = String(field.value);
                                    return;
                                }
                                editor.setValue(field.modelData.key, text);
                            }
                        }
                        ComboBox {
                            visible: !!field.modelData.choices
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "value"
                            model: field.modelData.choices || []
                            currentIndex: model.findIndex(c => c.value === field.value)
                            onActivated: editor.setValue(field.modelData.key, currentValue)
                        }
                        SpinBox {
                            visible: field.modelData.type === "Int"
                            editable: true
                            from: field.modelData.min || 0
                            to: field.modelData.max || 100000
                            value: field.modelData.type === "Int" ? Number(field.value) : 0
                            onValueModified: editor.setValue(field.modelData.key, value)
                        }
                        RowLayout {
                            visible: field.modelData.type === "Double"
                            Layout.fillWidth: true
                            Slider {
                                Layout.fillWidth: true
                                from: field.modelData.min || 0
                                to: field.modelData.max || 2
                                value: field.modelData.type === "Double" ? Number(field.value) : 0
                                stepSize: field.modelData.key === "fontScale" ? .05 : 1
                                onMoved: editor.setValue(field.modelData.key, value)
                            }
                            Text {
                                text: field.modelData.type === "Double" ? Number(field.value).toFixed(2) : ""
                                color: UI.Theme.textColor
                                font: UI.Theme.smallFont
                            }
                        }
                        ColumnLayout {
                            visible: field.modelData.key === "customCommands"
                            Layout.fillWidth: true
                            Repeater {
                                model: field.modelData.key === "customCommands" ? editor.commandArray() : []
                                ColumnLayout {
                                    id: cmdRow
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    RowLayout {
                                        Layout.fillWidth: true
                                        TextField {
                                            Layout.fillWidth: true
                                            text: cmdRow.modelData.label
                                            placeholderText: qsTr("Button label")
                                            onEditingFinished: if (text !== cmdRow.modelData.label)
                                                editor.changeCommand(cmdRow.index, "label", text)
                                        }
                                        ComboBox {
                                            model: ["accent", "green", "red", "default"]
                                            currentIndex: Math.max(0, model.indexOf(cmdRow.modelData.color || "accent"))
                                            onActivated: editor.changeCommand(cmdRow.index, "color", currentText)
                                        }
                                        UI.ActionButton {
                                            text: "×"
                                            tip: qsTr("Remove command")
                                            onClicked: {
                                                const list = editor.commandArray();
                                                list.splice(cmdRow.index, 1);
                                                editor.settings.customCommands = JSON.stringify(list);
                                            }
                                        }
                                    }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: cmdRow.modelData.cmd
                                        placeholderText: qsTr("Command, e.g. upnix")
                                        onEditingFinished: if (text !== cmdRow.modelData.cmd)
                                            editor.changeCommand(cmdRow.index, "cmd", text)
                                    }
                                }
                            }
                            UI.ActionButton {
                                text: qsTr("Add command")
                                enabled: editor.commandArray().length < 4
                                onClicked: {
                                    const list = editor.commandArray();
                                    list.push({
                                        label: "",
                                        cmd: "",
                                        color: "accent"
                                    });
                                    editor.settings.customCommands = JSON.stringify(list);
                                }
                            }
                        }
                        Text {
                            visible: field.modelData.help !== ""
                            Layout.fillWidth: true
                            text: field.modelData.help
                            wrapMode: Text.WordWrap
                            color: UI.Theme.muted
                            font: UI.Theme.smallFont
                        }
                    }
                }
                ColumnLayout {
                    visible: editor.hyprland && editor.currentTab === 3
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Hyprland panel")
                        color: UI.Theme.highlightColor
                        font: UI.Theme.defaultFont
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        model: [
                            {
                                label: qsTr("Always show pill"),
                                value: "always"
                            },
                            {
                                label: qsTr("Reveal at screen edge"),
                                value: "hover"
                            },
                            {
                                label: qsTr("Tray only"),
                                value: "tray"
                            }
                        ]
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: model.findIndex(c => c.value === editor.settings.pillMode)
                        onActivated: editor.settings.pillMode = currentValue
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]
                        currentIndex: Math.max(0, model.indexOf(editor.settings.popupPosition))
                        onActivated: editor.settings.popupPosition = currentText
                    }
                }
            }
        }
    }
}
