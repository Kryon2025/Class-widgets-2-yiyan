import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick 2.15 as Quick
import RinUI
import ClassWidgets.Theme

Widget {
    id: root
    text: qsTr("每日一言")

    // 固定组件宽度（不被内容撑变），高度保持与其他组件一致的标准高度
    implicitWidth: 380

    // 内容可视宽度 = 组件宽度 - 左右内边距（mini 16×2，普通 24×2）
    property real contentWidth: root.width - (root.miniMode ? 32 : 48)

    // 内容是否超出可视高度（超出才滚动）
    property bool overflow: backend.dailyQuoteStatus === "ok" && col.height / 2 > scrollBox.height
    // 滚动开关跟随设置变化（数值变化时触发 restartScroll 重新居中/重启）
    property bool scrollActive: settings.auto_scroll && root.overflow
    onScrollActiveChanged: scrollBox.restartScroll()

    // 加载 / 错误状态提示
    Quick.Text {
        id: statusText
        anchors.centerIn: parent
        width: root.contentWidth
        visible: backend.dailyQuoteStatus !== "ok"
        text: backend.dailyQuoteStatus === "error" ? qsTr("网络连接异常，5分钟后自动重试") : qsTr("加载中，请稍后...")
        horizontalAlignment: Quick.Text.AlignHCenter
        wrapMode: Quick.Text.Wrap
        color: Theme.currentTheme.colors.textSecondaryColor
        font.pixelSize: 13
    }

    // 内容区：固定宽度内自动换行，超出可视区域的部分隐藏，垂直无缝循环滚动
    Item {
        id: scrollBox
        anchors.fill: parent
        clip: true
        visible: backend.dailyQuoteStatus === "ok"

        Column {
            id: col
            width: root.contentWidth
            spacing: 0

            // 内容块 ×2（完全一致，滚动周期无缝）
            Quick.Text {
                width: col.width
                text: backend.dailyQuoteContent
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Theme.currentTheme.colors.textColor
                wrapMode: Quick.Text.Wrap  // 按组件宽度自动换行，不横向溢出
                horizontalAlignment: Quick.Text.AlignHCenter
                lineHeight: 1.3
            }
            Quick.Text {
                width: col.width
                text: "—— " + backend.dailyQuoteAuthor
                font.pixelSize: 12
                color: Theme.currentTheme.colors.textSecondaryColor
                horizontalAlignment: Quick.Text.AlignRight
                topPadding: 4   // 正文与作者间距
                bottomPadding: 4 // 块尾间距（与块内间距一致，保证滚动无缝）
            }
            Quick.Text {
                width: col.width
                text: backend.dailyQuoteContent
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Theme.currentTheme.colors.textColor
                wrapMode: Quick.Text.Wrap
                horizontalAlignment: Quick.Text.AlignHCenter
                lineHeight: 1.3
            }
            Quick.Text {
                width: col.width
                text: "—— " + backend.dailyQuoteAuthor
                font.pixelSize: 12
                color: Theme.currentTheme.colors.textSecondaryColor
                horizontalAlignment: Quick.Text.AlignRight
                topPadding: 4
                bottomPadding: 4
            }
        }

        function restartScroll() {
            scrollAnim.stop()
            if (root.scrollActive) {
                col.y = 0
                scrollAnim.restart()
            } else {
                // 内容放得下时垂直居中静止显示（从第一行开始）
                col.y = Math.max(0, (scrollBox.height - col.height / 2) / 2)
            }
        }

        SequentialAnimation {
            id: scrollAnim
            loops: Animation.Infinite
            NumberAnimation {
                target: col
                property: "y"
                from: 0
                to: -col.height / 2
                duration: Math.max(500, (col.height / 2) / Math.max(1, settings.scroll_speed) * 1000)
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: Math.max(0, settings.scroll_pause) }
        }

        Connections {
            target: backend
            function onDailyQuoteStatusChanged() { scrollBox.restartScroll() }
            function onDailyQuoteContentChanged() { scrollBox.restartScroll() }
        }

        Component.onCompleted: scrollBox.restartScroll()
    }
}
