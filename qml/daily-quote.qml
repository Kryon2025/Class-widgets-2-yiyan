import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick 2.15 as Quick
import RinUI
import ClassWidgets.Theme

Widget {
    id: root
    text: qsTr("每日一言")

    // 固定默认组件宽度（不被内容撑变）；自定义尺寸通过下方 Binding 覆盖
    implicitWidth: 380

    // 字体：同步主程序设置 / 自定义字号与字体
    property bool syncFont: settings.sync_main_font !== false
    property string mainFamily: {
        try {
            if (typeof Configs !== "undefined" && Configs.data && Configs.data.preferences)
                return Configs.data.preferences.font || ""
        } catch (e) {}
        return ""
    }
    property string fam: root.syncFont ? root.mainFamily : (settings.font_family || "")
    property int fs: (settings.font_size && settings.font_size > 0) ? settings.font_size : 16
    property int authorFs: Math.max(9, Math.round(root.fs * 0.75))
    // 译文字号：可单独设置；未设置时按原文字号比例自动推算
    property int transFs: (settings.translation_font_size && settings.translation_font_size > 0)
                          ? settings.translation_font_size
                          : Math.max(9, Math.round(root.fs * 0.78))

    // 滚动方式：auto（纵向循环）/ none（不滚动）/ hscroll（横向从右到左）
    property string scrollMode: settings.scroll_mode || "auto"

    // 英文一言（含译文）播放顺序：true = 先播完原文再播译文；false = 原文/译文双行同屏
    property bool translationAfter: settings.translation_after !== false

    // ── 显示层：内容切换时先淡出再淡入（渐变），避免文字硬切 ──
    property string dispContent: ""
    property string dispTranslation: ""
    property string dispAuthor: ""
    // 内容是否有译文（英文一言）：决定横向是否双行显示
    property bool bilingual: root.dispTranslation !== ""

    function applyContent() {
        if (!backend) return
        root.dispContent = backend.dailyQuoteContent
        root.dispTranslation = backend.dailyQuoteTranslation
        root.dispAuthor = backend.dailyQuoteAuthor
    }

    // 自定义组件框大小：仅在设置 > 0 时覆盖基类隐式尺寸，否则还原基类绑定
    Binding {
        target: root
        property: "implicitWidth"
        value: settings.box_width
        when: settings.box_width && settings.box_width > 0
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: root
        property: "implicitHeight"
        value: settings.box_height
        when: settings.box_height && settings.box_height > 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    // 内容可视宽度 = 组件宽度 - 左右内边距（mini 16×2，普通 24×2）
    property real contentWidth: root.width - (root.miniMode ? 32 : 48)

    // 加载 / 错误状态提示
    Quick.Text {
        id: statusText
        anchors.centerIn: parent
        width: root.contentWidth
        visible: backend.dailyQuoteStatus !== "ok"
        text: backend.dailyQuoteStatus === "error" ? qsTr("网络连接异常，5分钟后自动重试") : qsTr("加载中，请稍后...")
        horizontalAlignment: Quick.Text.AlignHCenter
        wrapMode: Quick.Text.Wrap
        font.family: root.fam
        color: Theme.currentTheme.colors.textSecondaryColor
        font.pixelSize: 13
    }

    // ── 内容层（三种模式共用，负责切换渐变）────────────────
    Item {
        id: contentLayer
        anchors.fill: parent
        opacity: 1

        // ── 纵向滚动（默认）────────────────────────────────
        Item {
            id: scrollBox
            anchors.fill: parent
            clip: true
            visible: backend.dailyQuoteStatus === "ok" && root.scrollMode === "auto"

            property bool overflow: backend.dailyQuoteStatus === "ok" && col.height / 2 > scrollBox.height
            property bool scrollActive: settings.auto_scroll && overflow
            onOverflowChanged: restartScroll()
            onScrollActiveChanged: restartScroll()

            // 滚动位移（像素）与剩余停留时间（毫秒）：由 Timer 每帧按「当前」设置推进，
            // 因此在设置页改「滚动速度 / 循环停留」会立刻生效，不必等本轮播完
            property real offset: 0
            property real pauseLeft: 0

            Column {
                id: col
                y: scrollBox.scrollActive
                    ? -scrollBox.offset
                    : Math.max(0, (scrollBox.height - col.height / 2) / 2)
                width: root.contentWidth
                spacing: 0

                // 内容块 ×2（完全一致，滚动周期无缝）
                Quick.Text {
                    width: col.width
                    text: root.dispContent
                    font.family: root.fam
                    font.pixelSize: root.fs
                    font.weight: Font.DemiBold
                    color: Theme.currentTheme.colors.textColor
                    wrapMode: Quick.Text.Wrap
                    horizontalAlignment: Quick.Text.AlignHCenter
                    lineHeight: 1.3
                }
                Quick.Text {
                    width: col.width
                    text: root.dispTranslation
                    visible: text !== ""
                    font.family: root.fam
                    font.pixelSize: root.transFs
                    color: root.translationAfter ? Theme.currentTheme.colors.textColor : Theme.currentTheme.colors.textSecondaryColor
                    wrapMode: Quick.Text.Wrap
                    horizontalAlignment: Quick.Text.AlignHCenter
                    topPadding: 4
                }
                Quick.Text {
                    width: col.width
                    text: "—— " + root.dispAuthor
                    font.family: root.fam
                    font.pixelSize: root.authorFs
                    color: Theme.currentTheme.colors.textSecondaryColor
                    horizontalAlignment: Quick.Text.AlignRight
                    topPadding: 4
                    bottomPadding: 4
                }
                Quick.Text {
                    width: col.width
                    text: root.dispContent
                    font.family: root.fam
                    font.pixelSize: root.fs
                    font.weight: Font.DemiBold
                    color: Theme.currentTheme.colors.textColor
                    wrapMode: Quick.Text.Wrap
                    horizontalAlignment: Quick.Text.AlignHCenter
                    lineHeight: 1.3
                }
                Quick.Text {
                    width: col.width
                    text: root.dispTranslation
                    visible: text !== ""
                    font.family: root.fam
                    font.pixelSize: root.transFs
                    color: root.translationAfter ? Theme.currentTheme.colors.textColor : Theme.currentTheme.colors.textSecondaryColor
                    wrapMode: Quick.Text.Wrap
                    horizontalAlignment: Quick.Text.AlignHCenter
                    topPadding: 4
                }
                Quick.Text {
                    width: col.width
                    text: "—— " + root.dispAuthor
                    font.family: root.fam
                    font.pixelSize: root.authorFs
                    color: Theme.currentTheme.colors.textSecondaryColor
                    horizontalAlignment: Quick.Text.AlignRight
                    topPadding: 4
                    bottomPadding: 4
                }
            }

            function restartScroll() {
                scrollBox.offset = 0
                scrollBox.pauseLeft = 0
            }

            // 逐帧推进：速度 / 停留时间每帧重新读取，改设置立即生效
            Timer {
                interval: 16
                repeat: true
                running: scrollBox.scrollActive
                onTriggered: {
                    var cycle = col.height / 2
                    if (cycle <= 0) return
                    if (scrollBox.pauseLeft > 0) {
                        scrollBox.pauseLeft = Math.max(0, scrollBox.pauseLeft - interval)
                        return
                    }
                    scrollBox.offset += Math.max(1, settings.scroll_speed || 40) * interval / 1000
                    if (scrollBox.offset >= cycle) {
                        // 一轮滚完（新的开头到达顶部）：回到等价起点并停留设定时长
                        scrollBox.offset -= cycle
                        scrollBox.pauseLeft = Math.max(0, settings.scroll_pause || 0)
                        // 本条已完整播放一轮：通知后端可切换到下一条
                        if (backend) backend.onQuotePlaybackFinished()
                    }
                }
            }

            Connections {
                target: backend
                function onDailyQuoteChanged() { scrollBox.restartScroll() }
            }
            Connections {
                target: root
                function onDispContentChanged() { scrollBox.restartScroll() }
            }

            Component.onCompleted: scrollBox.restartScroll()
        }

        // ── 横向滚动（从右到左）────────────────────────────
        // 中文/诗词：单行；英文一言（有译文）：双行 —— 上原文、下译文。
        Item {
            id: hsBox
            anchors.fill: parent
            clip: true
            visible: backend.dailyQuoteStatus === "ok" && root.scrollMode === "hscroll"

            property real offset: 0
            property real pauseLeft: 0
            property bool pausedAtStop: false
            property bool transPhase: false   // false = 正在播原文；true = 正在播译文

            function resetScroll() {
                hsBox.offset = 0
                hsBox.pauseLeft = 0
                hsBox.pausedAtStop = false
                hsBox.transPhase = false
            }

            // 双行（英文）/ 单行（其它）：整体一起横向滚动
            Column {
                id: hsCol
                spacing: Math.max(3, Math.round(root.fs * 0.28))   // 行距随字号，避免两行叠在一起
                x: hsBox.width - hsBox.offset
                y: (hsBox.height - hsCol.height) / 2

                // 译文行：仅英文 +（双行模式 或 已进入译文阶段）时显示
                Quick.Text {
                    id: hsTrans
                    text: root.dispTranslation
                    visible: root.bilingual && (!root.translationAfter || hsBox.transPhase)
                    font.family: root.fam
                    font.pixelSize: root.transFs
                    color: root.translationAfter ? Theme.currentTheme.colors.textColor : Theme.currentTheme.colors.textSecondaryColor
                }
                // 原文行：单行模式进入译文阶段时隐藏（作者跟在原文后）
                Quick.Text {
                    id: hsOrigin
                    text: root.dispContent
                          + (root.dispAuthor ? "    —— " + root.dispAuthor : "")
                    visible: !root.translationAfter || !hsBox.transPhase
                    font.family: root.fam
                    font.pixelSize: root.fs
                    font.weight: Font.DemiBold
                    color: Theme.currentTheme.colors.textColor
                }
            }

            Timer {
                interval: 16
                repeat: true
                running: root.scrollMode === "hscroll" && hsCol.width > 0
                onTriggered: {
                    var total = hsBox.width + hsCol.width
                    if (total <= 0) return
                    if (hsBox.pauseLeft > 0) {
                        hsBox.pauseLeft = Math.max(0, hsBox.pauseLeft - interval)
                        return
                    }
                    var stopAt = hsBox.width
                    hsBox.offset += Math.max(10, settings.scroll_speed || 40) * interval / 1000
                    if (!hsBox.pausedAtStop && hsBox.offset >= stopAt) {
                        hsBox.offset = stopAt
                        hsBox.pauseLeft = Math.max(0, settings.scroll_pause || 0)
                        hsBox.pausedAtStop = true
                        return
                    }
                    if (hsBox.offset >= total) {
                        hsBox.offset = 0
                        hsBox.pausedAtStop = false
                        // 先原文后译文：原文播完 → 转入译文阶段再播一遍
                        if (root.translationAfter && root.bilingual && !hsBox.transPhase) {
                            hsBox.transPhase = true
                            return
                        }
                        // 一条（含译文阶段）播完：回到原文阶段并通知后端
                        hsBox.transPhase = false
                        if (backend) backend.onQuotePlaybackFinished()
                    }
                }
            }
            // 内容更换时从头（原文阶段）开始
            Connections {
                target: root
                function onDispContentChanged() { hsBox.resetScroll() }
            }
            onWidthChanged: resetScroll()
            onVisibleChanged: if (visible) resetScroll()
            Component.onCompleted: resetScroll()
        }

        // ── 不滚动（内容居中，超出裁剪）────────────────────
        Item {
            id: noneBox
            anchors.fill: parent
            clip: true
            visible: backend.dailyQuoteStatus === "ok" && root.scrollMode === "none"

            Column {
                width: root.contentWidth
                anchors.centerIn: parent
                spacing: 0

                Quick.Text {
                    width: parent.width
                    text: root.dispContent
                    font.family: root.fam
                    font.pixelSize: root.fs
                    font.weight: Font.DemiBold
                    color: Theme.currentTheme.colors.textColor
                    wrapMode: Quick.Text.Wrap
                    horizontalAlignment: Quick.Text.AlignHCenter
                    lineHeight: 1.3
                }
                Quick.Text {
                    width: parent.width
                    text: root.dispTranslation
                    visible: text !== ""
                    font.family: root.fam
                    font.pixelSize: root.transFs
                    color: root.translationAfter ? Theme.currentTheme.colors.textColor : Theme.currentTheme.colors.textSecondaryColor
                    wrapMode: Quick.Text.Wrap
                    horizontalAlignment: Quick.Text.AlignHCenter
                    topPadding: 4
                }
                Quick.Text {
                    width: parent.width
                    text: "—— " + root.dispAuthor
                    font.family: root.fam
                    font.pixelSize: root.authorFs
                    color: Theme.currentTheme.colors.textSecondaryColor
                    horizontalAlignment: Quick.Text.AlignRight
                    topPadding: 4
                }
            }
        }
    }

    // 内容切换渐变：淡出 → 应用新内容 → 淡入
    SequentialAnimation {
        id: switchFade
        NumberAnimation { target: contentLayer; property: "opacity"; to: 0; duration: 160 }
        ScriptAction { script: root.applyContent() }
        NumberAnimation { target: contentLayer; property: "opacity"; to: 1; duration: 280 }
    }

    // 内容静止展示（不滚动）时的兜底「播完」计时：只有内容完整停留在屏上时才计时
    Timer {
        id: dwellTimer
        interval: Math.max(6000, (settings.scroll_pause || 0) + 6000)
        repeat: true
        running: backend.dailyQuoteStatus === "ok"
                 && (root.scrollMode === "none"
                     || (root.scrollMode === "auto" && !scrollBox.overflow))
        onTriggered: if (backend) backend.onQuotePlaybackFinished()
    }

    Connections {
        target: backend
        function onDailyQuoteChanged() { Qt.callLater(root.refreshQuote) }
    }

    // 后端数据可能晚于组件创建：内容不同才应用；同内容不动，避免无意义动画干扰显示
    function refreshQuote() {
        if (backend && root.dispContent !== backend.dailyQuoteContent)
            root.applyContent()
    }

    // 把「主程序字体」回传给后端，供桌面一言在未单独设字体时同步
    onMainFamilyChanged: if (backend) backend.setMainFont(root.mainFamily)

    Component.onCompleted: {
        console.log("[daily.quote] onCompleted status=" + (backend ? backend.dailyQuoteStatus : "NO_BACKEND")
                    + " content=" + (backend && backend.dailyQuoteContent !== "" ? backend.dailyQuoteContent.slice(0, 12) : "<空>")
                    + " sources=" + (settings ? JSON.stringify(settings.sources || []) : "NO_SETTINGS"))
        // 启动时把设置页保存的来源/轮播配置同步给后端：后端启动时不会自己读配置，
        // 默认按中文抓取，导致「设置是英文、组件却播中文」。
        if (backend && settings) {
            var srcs = (settings.sources && settings.sources.length) ? settings.sources : ["cn"]
            backend.setRotationConfig(srcs, settings.switch_mode || "lesson", settings.switch_interval || 300000)
        }
        root.applyContent()
        if (backend) backend.setMainFont(root.mainFamily)
        // 组件可能先于抓取创建：内容为空时主动请后端抓取一次
        if (backend && backend.dailyQuoteContent === "") backend.refresh()
        // 启动时后端/设置可能尚未就绪：短暂轮询补齐，确保「一启动就播放」
        startupTimer.start()
    }

    // 启动补齐：只在前几秒、且内容确实没拿到时补一次，避免与正常切换互相干扰
    Timer {
        id: startupTimer
        interval: 250
        repeat: true
        property int tries: 0
        onTriggered: {
            tries += 1
            // settings 可能是异步加载的：检测到来源变化就同步给后端（幂等比较，不重复抓取）
            if (backend && settings) {
                var srcs = (settings.sources && settings.sources.length) ? settings.sources : ["cn"]
                var cur = backend.enabledSources()
                if (JSON.stringify(srcs) !== JSON.stringify(cur))
                    backend.setRotationConfig(srcs, settings.switch_mode || "lesson", settings.switch_interval || 300000)
            }
            if (root.dispContent === "" && backend && backend.dailyQuoteContent !== "")
                root.applyContent()
            if (tries >= 24) stop()
        }
    }
}
