// 桌面一言窗口（由插件后端以 QQuickView 承载，无边框、置顶、默认右上角）。
// 通过上下文属性 quoteBackend 读取配置；编辑模式下可拖动/缩放并“确定”。
import QtQuick
import QtQuick.Controls

Item {
    id: rect
    width: parent ? parent.width : 380
    height: parent ? parent.height : 160

    property var quotes: {
        try { return JSON.parse(quoteBackend.deskQuotesJson) } catch (e) { return [] }
    }
    property int fs: quoteBackend.deskFontSize
    // 字体：优先用桌面单独选择的字体；未单独设置则同步主程序「字体」设置项
    property string fam: quoteBackend.deskFontFamily !== ""
                         ? quoteBackend.deskFontFamily
                         : quoteBackend.mainFontFamily
    property color tcolor: quoteBackend.deskTextColor
    property bool bgOn: quoteBackend.deskBgEnabled
    property real bgOp: quoteBackend.deskBgOpacity
    property bool showAuthor: quoteBackend.deskShowAuthor
    property bool editing: quoteBackend.deskEdit

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: rect.bgOn ? Qt.rgba(0, 0, 0, rect.bgOp) : "transparent"
        border.color: rect.editing ? "#4a90d9" : "transparent"
        border.width: rect.editing ? 2 : 0

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            clip: true

            Repeater {
                model: rect.quotes
                delegate: Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.content
                        color: rect.tcolor
                        font.family: rect.fam
                        font.pixelSize: rect.fs
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.translation || ""
                        visible: text !== ""
                        color: rect.tcolor
                        opacity: 0.85
                        font.family: rect.fam
                        font.pixelSize: Math.max(9, Math.round(rect.fs * 0.72))
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        visible: rect.showAuthor
                        text: "—— " + modelData.author
                        color: rect.tcolor
                        opacity: 0.75
                        font.family: rect.fam
                        font.pixelSize: Math.max(9, Math.round(rect.fs * 0.72))
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // 编辑模式：整体拖动移动窗口 + 右下角缩放 + 确定按钮
    Item {
        anchors.fill: parent
        visible: rect.editing

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            property real lastX: 0
            property real lastY: 0
            onPressed: (mouse) => { lastX = mouse.x; lastY = mouse.y }
            onPositionChanged: (mouse) => {
                quoteBackend.moveDesktopBy(mouse.x - lastX, mouse.y - lastY)
                lastX = mouse.x
                lastY = mouse.y
            }
        }

        Rectangle {
            width: 18
            height: 18
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: "#4a90d9"
            radius: 3

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor
                property real sx: 0
                property real sy: 0
                property real sw: 380
                property real sh: 160
                onPressed: (mouse) => { sx = mouse.x; sy = mouse.y; sw = rect.width; sh = rect.height }
                onPositionChanged: (mouse) => {
                    quoteBackend.resizeDesktop(sw + (mouse.x - sx), sh + (mouse.y - sy))
                }
            }
        }

        Button {
            text: qsTr("确定")
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
            onClicked: quoteBackend.confirmDesktopEdit()
        }
    }
}
