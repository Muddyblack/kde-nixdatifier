import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// Inline explanation, or a tinted warning when `emphasis` is set.
Rectangle {
    id: notice
    property string text: ""
    property string glyph: "ic_info"
    property color tone: "#8c9db5"
    property bool emphasis: false
    property real fs: 1
    implicitHeight: row.implicitHeight + 22
    radius: 7
    color: emphasis ? UI.Theme.wash(tone, .06) : "#03ffffff"
    border.color: emphasis ? UI.Theme.wash(tone, .22) : "#0dffffff"
    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 11
        spacing: 8
        UI.Icon {
            Layout.alignment: Qt.AlignTop
            source: Qt.resolvedUrl("../assets/" + notice.glyph + ".svg")
            implicitWidth: 13
            implicitHeight: 13
            isMask: true
            color: notice.tone
        }
        Text {
            Layout.fillWidth: true
            text: notice.text
            textFormat: Text.PlainText
            color: notice.tone
            font.pixelSize: UI.Theme.fontPx(9, notice.fs)
            wrapMode: Text.Wrap
            lineHeight: 1.5
        }
    }
}
