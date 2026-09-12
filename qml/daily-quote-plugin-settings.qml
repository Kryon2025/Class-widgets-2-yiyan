import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import RinUI
import ClassWidgets.Plugins

PluginPage {
    id: page
    pluginId: "com.daily.quote"
    title: qsTr("每日一言")

    property bool deskEnabled: false
    property var deskSources: ["cn"]
    property string textColor: "#ffffff"
    property bool bgEnabled: false
    property real bgOpacity: 0.5
    property bool showAuthor: true
    property string deskLayer: "bottom"
    property string deskFontFamily: ""
    property bool syncing: false

    Component.onCompleted: reload()
    onBackendChanged: if (backend) reload()

    function reload() {
        if (!backend) return
        page.syncing = true
        var cfg = { "enabled": false, "config": {} }
        try { cfg = JSON.parse(backend.getDesktopConfigJson()) } catch (e) {}
        var c = cfg.config || {}
        page.deskEnabled = cfg.enabled === true
        page.deskSources = c.sources ? c.sources.slice() : ["cn"]
        page.textColor = c.textColor || "#ffffff"
        page.bgEnabled = c.bgEnabled === true
        page.bgOpacity = c.bgOpacity !== undefined ? c.bgOpacity : 0.5
        page.showAuthor = c.showAuthor !== false
        page.deskLayer = c.layer || "bottom"
        page.deskFontFamily = c.fontFamily || ""
        page.syncing = false
    }

    function push() {
        if (page.syncing || !backend) return
        backend.setDesktopConfigJson(JSON.stringify({
            "sources": page.deskSources,
            "textColor": page.textColor,
            "bgEnabled": page.bgEnabled,
            "bgOpacity": page.bgOpacity,
            "showAuthor": page.showAuthor,
            "layer": page.deskLayer,
            "fontFamily": page.deskFontFamily
        }))
    }

    function toggleDeskSrc(id, on) {
        var s = page.deskSources.slice()
        var i = s.indexOf(id)
        if (on && i < 0) s.push(id)
        else if (!on && i >= 0) s.splice(i, 1)
        page.deskSources = s
        page.push()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("桌面一言模式")
            description: qsTr("在桌面右上角常驻显示一言，不超出屏幕边缘。默认关闭。")

            Switch {
                text: qsTr("启用")
                checked: page.deskEnabled
                onCheckedChanged: {
                    page.deskEnabled = checked
                    if (backend) backend.setDesktopEnabled(checked)
                }
            }
        }

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("桌面展示类型")
            description: qsTr("选择在桌面展示的一言类型，可同时展示多种。")
            enabled: page.deskEnabled

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Switch { text: qsTr("中文一言"); checked: page.deskSources.indexOf("cn") >= 0; onCheckedChanged: page.toggleDeskSrc("cn", checked) }
                Switch { text: qsTr("英文一言"); checked: page.deskSources.indexOf("en") >= 0; onCheckedChanged: page.toggleDeskSrc("en", checked) }
                Switch { text: qsTr("诗词"); checked: page.deskSources.indexOf("poem") >= 0; onCheckedChanged: page.toggleDeskSrc("poem", checked) }
                Switch { text: qsTr("显示作者"); checked: page.showAuthor; onCheckedChanged: { page.showAuthor = checked; page.push() } }
            }
        }

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("字体颜色")
            description: qsTr("桌面一言的字体颜色，可使用系统调色盘。字体同步主程序设置。")
            enabled: page.deskEnabled

            RowLayout {
                spacing: 12
                Rectangle {
                    width: 40
                    height: 24
                    radius: 4
                    color: page.textColor
                    border.color: "#888888"
                    border.width: 1
                }
                Button {
                    text: qsTr("选择颜色")
                    onClicked: colorDialog.open()
                }
            }

            ColorDialog {
                id: colorDialog
                selectedColor: page.textColor
                onAccepted: { page.textColor = selectedColor; page.push() }
            }
        }

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("字体")
            description: qsTr("桌面一言的字体。可选择系统字体；未单独设置时同步主程序字体。")
            enabled: page.deskEnabled

            ComboBox {
                id: fontCombo
                Layout.preferredWidth: 220
                editable: true
                model: Qt.fontFamilies().sort()
                onActivated: { page.deskFontFamily = currentText; page.push() }
                onAccepted: { page.deskFontFamily = currentText; page.push() }
                Component.onCompleted: {
                    var mainFont = ""
                    try { mainFont = Configs.data.preferences.font || "" } catch (e) {}
                    var saved = page.deskFontFamily !== "" ? page.deskFontFamily : mainFont
                    var i = model.indexOf(saved)
                    currentIndex = i >= 0 ? i : 0
                }
            }
        }

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("背景")
            description: qsTr("默认透明背景；可开启不透明背景并调节透明度。")
            enabled: page.deskEnabled

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Switch {
                    text: qsTr("启用不透明背景")
                    checked: page.bgEnabled
                    onCheckedChanged: { page.bgEnabled = checked; page.push() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Slider {
                        Layout.fillWidth: true
                        from: 0.0
                        to: 1.0
                        stepSize: 0.05
                        value: page.bgOpacity
                        onMoved: { page.bgOpacity = value; page.push() }
                    }
                    Text {
                        Layout.preferredWidth: 50
                        text: Math.round(page.bgOpacity * 100) + "%"
                    }
                }
            }
        }

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("窗口层级")
            description: qsTr("桌面一言的显示层级：置顶浮于所有窗口之上；置底贴桌面（会被其它窗口遮挡）；普通随窗口正常排列。")
            enabled: page.deskEnabled

            ComboBox {
                Layout.preferredWidth: 220
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: qsTr("置底"), value: "bottom" },
                    { text: qsTr("置顶"), value: "top" },
                    { text: qsTr("普通"), value: "normal" }
                ]
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.deskLayer || "bottom"))
                onActivated: { page.deskLayer = currentValue; page.push() }
            }
        }

        SettingCard {
            Layout.fillWidth: true
            title: qsTr("编辑桌面一言")
            description: qsTr("点击后回到桌面并打开编辑框：可拖动/缩放窗口，一言仅在设定范围内展示并自适应字号。点“确定”返回。")
            enabled: page.deskEnabled

            RowLayout {
                spacing: 8
                Button {
                    text: qsTr("编辑")
                    onClicked: if (backend) backend.setDesktopEditMode(true)
                }
                Button {
                    text: qsTr("重置位置")
                    onClicked: if (backend) backend.resetDesktopPos()
                }
            }
        }
    }
}
