import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI
import ClassWidgets.Plugins

SettingsLayout {
    // 滚动速度当前值（像素/秒），始终与显示同步
    property int speedValue: 40
    onSpeedValueChanged: settings.scroll_speed = speedValue

    // 循环间隔当前值（秒），始终与显示同步；内部以毫秒存储
    property int pauseSec: 1
    onPauseSecChanged: settings.scroll_pause = pauseSec * 1000

    // 一次性读取持久化设置（旧实例可能缺少新键，缺省回退默认值）
    Component.onCompleted: {
        speedValue = settings.scroll_speed !== undefined ? settings.scroll_speed : 40
        // 旧版本以毫秒存储，此处换算为秒
        pauseSec = Math.max(0, Math.round((settings.scroll_pause !== undefined ? settings.scroll_pause : 1200) / 1000))
    }

    SettingCard {
        Layout.fillWidth: true
        title: "自动滚动"
        description: "内容超出组件高度时自动向上滚动。"

        Switch {
            checked: settings.auto_scroll
            onCheckedChanged: settings.auto_scroll = checked
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "滚动速度"
        description: "自动滚动的速度（像素/秒），点击加减按钮以 10 调整。"
        enabled: settings.auto_scroll

        RowLayout {
            spacing: 8
            Button {
                text: "−"
                implicitWidth: 36
                onClicked: speedValue = Math.max(10, speedValue - 10)
            }
            Text {
                Layout.preferredWidth: 80
                horizontalAlignment: Text.AlignHCenter
                text: speedValue + " px/s"
            }
            Button {
                text: "+"
                implicitWidth: 36
                onClicked: speedValue = Math.min(120, speedValue + 10)
            }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "循环间隔"
        description: "每一轮滚动结束后停留的时间（秒），之后开始下一轮滚动，0 表示不停留。"
        enabled: settings.auto_scroll

        RowLayout {
            spacing: 8
            Button {
                text: "−"
                implicitWidth: 36
                onClicked: pauseSec = Math.max(0, pauseSec - 1)
            }
            Text {
                Layout.preferredWidth: 70
                horizontalAlignment: Text.AlignHCenter
                text: pauseSec + " 秒"
            }
            Button {
                text: "+"
                implicitWidth: 36
                onClicked: pauseSec = Math.min(30, pauseSec + 1)
            }
        }
    }
}
