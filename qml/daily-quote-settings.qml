import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI
import ClassWidgets.Plugins

SettingsLayout {
    id: page

    // 主程序通过 setSource params 注入后端的参数名是 backendObj（不是 backend）。
    // 不声明它的话，本页里的 `backend` 就是未定义标识符，`if (backend)` 会直接失败，
    // 导致来源切换（setRotationConfig / setActiveSource）永远不执行——
    // 表现为「勾选了英文/诗词却始终显示中文」。
    property var backendObj: null
    property var backend: backendObj

    // 本地值：与设置双向同步
    property int speedValue: 40
    onSpeedValueChanged: settings.scroll_speed = speedValue
    property int pauseSec: 1
    onPauseSecChanged: settings.scroll_pause = pauseSec * 1000
    property int fontSizeValue: 16
    onFontSizeValueChanged: settings.font_size = fontSizeValue
    property int transFsValue: 0
    onTransFsValueChanged: settings.translation_font_size = transFsValue
    property bool transAfterValue: true
    onTransAfterValueChanged: settings.translation_after = transAfterValue
    property int boxW: 0
    property int boxH: 0
    property int switchMin: 5
    // 下面两个是「本地镜像」，只用来驱动控件的 visible / enabled。
    // 不能直接绑定 settings.switch_mode / settings.scroll_mode：
    // ComboBox 改值后这类绑定不会重新求值，会导致间隔控件一直隐藏、改不了循环间隔。
    property string modeValue: "lesson"
    property string scrollModeValue: "auto"

    Component.onCompleted: {
        speedValue = settings.scroll_speed !== undefined ? settings.scroll_speed : 40
        pauseSec = Math.max(0, Math.round((settings.scroll_pause !== undefined ? settings.scroll_pause : 1200) / 1000))
        fontSizeValue = settings.font_size !== undefined ? settings.font_size : 16
        transFsValue = settings.translation_font_size || 0
        transAfterValue = settings.translation_after !== false
        boxW = settings.box_width || 0
        boxH = settings.box_height || 0
        switchMin = Math.max(1, Math.round((settings.switch_interval || 300000) / 60000))
        modeValue = settings.switch_mode || "lesson"
        scrollModeValue = settings.scroll_mode || "auto"
        page.pushRotation()
    }

    function srcEnabled(id) {
        var s = settings.sources
        return !!s && s.indexOf(id) >= 0
    }

    function toggleSrc(id, on) {
        var s = (settings.sources || []).slice()
        var i = s.indexOf(id)
        if (on && i < 0) s.push(id)
        else if (!on && i >= 0) s.splice(i, 1)
        // 不再在此回填 ["cn"]：否则「先关中文、再开英文」会在关中文那一步
        // 被立刻回填成中文，最终变成 [中文, 英文]，组件仍显示中文。
        // 空数组交由后端兜底，保证用户操作顺序任意都能得到想要的结果。
        settings.sources = s
        page.pushRotation()
        // 打开某来源时立即切换到它展示（否则「每节课后」模式下要等到下课才轮播到）
        if (on && backend) backend.setActiveSource(id)
    }

    function pushRotation() {
        if (backend)
            // 直接用界面上的本地值，不依赖 settings 对象回读是否及时，
            // 保证用户点 +/− 后后端立刻拿到新的间隔
            backend.setRotationConfig(settings.sources || ["cn"],
                page.modeValue,
                Math.max(1, page.switchMin) * 60000)
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("滚动方式")
        description: qsTr("内容超出组件高度时的展示方式。")

        ComboBox {
            Layout.preferredWidth: 220
            textRole: "text"
            valueRole: "value"
            model: [
                { text: qsTr("纵向循环滚动"), value: "auto" },
                { text: qsTr("不滚动（居中）"), value: "none" },
                { text: qsTr("横向从右到左"), value: "hscroll" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(settings.scroll_mode || "auto"))
            onActivated: { settings.scroll_mode = currentValue; page.scrollModeValue = currentValue }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("滚动速度")
        description: qsTr("滚动速度（像素/秒），纵向与横向滚动通用。")
        enabled: page.scrollModeValue !== "none"

        RowLayout {
            spacing: 8
            Button { text: "−"; implicitWidth: 36; onClicked: speedValue = Math.max(10, speedValue - 10) }
            Text { Layout.preferredWidth: 80; horizontalAlignment: Text.AlignHCenter; text: speedValue + " px/s" }
            Button { text: "+"; implicitWidth: 36; onClicked: speedValue = Math.min(200, speedValue + 10) }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("循环停留")
        description: qsTr("纵向 / 横向滚动每轮结束后的停留时间（秒）。")
        enabled: page.scrollModeValue !== "none"

        RowLayout {
            spacing: 8
            Button { text: "−"; implicitWidth: 36; onClicked: pauseSec = Math.max(0, pauseSec - 1) }
            Text { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter; text: pauseSec + " 秒" }
            Button { text: "+"; implicitWidth: 36; onClicked: pauseSec = Math.min(30, pauseSec + 1) }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("字体")
        description: qsTr("字号与主程序字体同步设置。")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                spacing: 8
                Text { text: qsTr("正文字号"); Layout.preferredWidth: 60 }
                Button { text: "−"; implicitWidth: 36; onClicked: fontSizeValue = Math.max(10, fontSizeValue - 1) }
                Text { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter; text: fontSizeValue + " px" }
                Button { text: "+"; implicitWidth: 36; onClicked: fontSizeValue = Math.min(72, fontSizeValue + 1) }
            }
            RowLayout {
                spacing: 8
                Text { text: qsTr("译文字号"); Layout.preferredWidth: 60 }
                Button {
                    text: "−"; implicitWidth: 36
                    onClicked: transFsValue = Math.max(1, (transFsValue > 0 ? transFsValue : Math.round(fontSizeValue * 0.78)) - 1)
                }
                Text {
                    Layout.preferredWidth: 70
                    horizontalAlignment: Text.AlignHCenter
                    text: transFsValue > 0 ? (transFsValue + " px") : qsTr("自动")
                }
                Button {
                    text: "+"; implicitWidth: 36
                    onClicked: transFsValue = Math.min(72, (transFsValue > 0 ? transFsValue : Math.round(fontSizeValue * 0.78)) + 1)
                }
            }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("译文播放")
        description: qsTr("横向滚动时英文一言的播放顺序。")

        Switch {
            text: qsTr("播放完原文后播放译文")
            checked: page.transAfterValue
            onCheckedChanged: page.transAfterValue = checked
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("组件框大小")
        description: qsTr("自定义组件宽高（像素）；点“自适应”恢复默认。")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                spacing: 8
                Text { text: qsTr("宽"); Layout.preferredWidth: 30 }
                Button { text: "−"; implicitWidth: 36; onClicked: { boxW = Math.max(120, (boxW > 0 ? boxW : 380) - 20); settings.box_width = boxW } }
                Text { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter; text: (boxW > 0 ? boxW : 380) + " px" }
                Button { text: "+"; implicitWidth: 36; onClicked: { boxW = Math.min(1600, (boxW > 0 ? boxW : 380) + 20); settings.box_width = boxW } }
            }
            RowLayout {
                spacing: 8
                Text { text: qsTr("高"); Layout.preferredWidth: 30 }
                Button { text: "−"; implicitWidth: 36; onClicked: { boxH = Math.max(48, (boxH > 0 ? boxH : 120) - 10); settings.box_height = boxH } }
                Text { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter; text: (boxH > 0 ? boxH : 120) + " px" }
                Button { text: "+"; implicitWidth: 36; onClicked: { boxH = Math.min(1600, (boxH > 0 ? boxH : 120) + 10); settings.box_height = boxH } }
            }
            Button {
                text: qsTr("自适应")
                onClicked: { boxW = 0; boxH = 0; settings.box_width = 0; settings.box_height = 0 }
            }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("一言来源")
        description: qsTr("选择参与轮播的来源（至少开启一个）。一次只展示一个来源的句子。")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Switch { text: qsTr("中文一言"); checked: page.srcEnabled("cn"); onCheckedChanged: page.toggleSrc("cn", checked) }
            Switch { text: qsTr("英文一言"); checked: page.srcEnabled("en"); onCheckedChanged: page.toggleSrc("en", checked) }
            Switch { text: qsTr("诗词"); checked: page.srcEnabled("poem"); onCheckedChanged: page.toggleSrc("poem", checked) }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: qsTr("轮播方式")
        description: qsTr("开启两个及以上来源后，切换展示来源的时机。")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            ComboBox {
                Layout.preferredWidth: 240
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: qsTr("每节课后切换"), value: "lesson" },
                    { text: qsTr("按自定义间隔切换"), value: "interval" }
                ]
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(settings.switch_mode || "lesson"))
                onActivated: { settings.switch_mode = currentValue; page.modeValue = currentValue; page.pushRotation() }
            }
            RowLayout {
                spacing: 8
                visible: page.modeValue === "interval"
                Button { text: "−"; implicitWidth: 36; onClicked: { switchMin = Math.max(1, switchMin - 1); settings.switch_interval = switchMin * 60000; page.pushRotation() } }
                Text { Layout.preferredWidth: 90; horizontalAlignment: Text.AlignHCenter; text: switchMin + " 分钟" }
                Button { text: "+"; implicitWidth: 36; onClicked: { switchMin = Math.min(720, switchMin + 1); settings.switch_interval = switchMin * 60000; page.pushRotation() } }
            }
        }
    }
}
