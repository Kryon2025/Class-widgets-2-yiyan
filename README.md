<div align="center">

<img src="icon.png" height="120" alt="每日一言">
<h1>每日一言（Class Widgets 2）</h1>

<p>桌面组件 + 桌面一言，支持中文一言、英文一言（含译文）、诗词三个来源，可轮播。此插件由 Deepseek V4开发。</p>

[![版本](https://img.shields.io/badge/%E7%89%88%E6%9C%AC-1.2.2-5A9BFF?style=for-the-badge)](https://github.com/Kryon2025/Class-widgets-2-yiyan/releases)
[![星标](https://img.shields.io/github/stars/Kryon2025/Class-widgets-2-yiyan?style=for-the-badge&color=orange&label=%E6%98%9F%E6%A0%87)](https://github.com/Kryon2025/Class-widgets-2-yiyan)
[![开源许可](https://img.shields.io/github/license/Kryon2025/Class-widgets-2-yiyan?style=for-the-badge&label=%E5%BC%80%E6%BA%90%E8%AE%B8%E5%8F%AF%E8%AF%81)](https://github.com/Kryon2025/Class-widgets-2-yiyan/blob/main/LICENSE)
[![下载量](https://img.shields.io/github/downloads/Kryon2025/Class-widgets-2-yiyan/total.svg?label=%E4%B8%8B%E8%BD%BD%E9%87%8F&color=green&style=for-the-badge)](https://github.com/Kryon2025/Class-widgets-2-yiyan/releases)

</div>

> [!NOTE]
> 当前版本 **1.2.2**，要求 Class Widgets 2 的插件 API `~=0.6.0`。
> 在 [插件广场](https://plaza.cw.rinlit.cn/plugins/com.daily.quote) 可以一键安装/更新，也可以在 Release 页下载 `.cwplugin` 手动导入。

## 功能

- **多来源**：中文一言 / 英文一言（扇贝每日一句，含中文译文）/ 诗词（今日诗词）
- **滚动方式**（设置页可选）：
  - 纵向循环（`auto`）：内容超出组件高度时向上循环滚动，速度与每轮停留时间可调
  - 横向滚动（`hscroll`）：从右到左单行滚动
  - 不滚动（`none`）：居中静止展示，超出裁剪
- **英文译文**：可设「先播完原文再播译文」，或「原文/译文双行同屏（并排）」；并排时译文使用次要颜色
- **来源轮播**：按「每节课」或「自定义间隔」自动切换来源；等当前一条完整播放完再切，不打断阅读
- **桌面一言**：独立桌面窗口，可贴桌面底层/顶层；字体、字号、颜色、背景、是否显示作者可调
- 每日 1 点自动更新；请求失败自动重试（失败后每 5 分钟再试）
- 组件宽高、字号、译文字号、字体（同步主程序或自定义）可调

## 配置持久化

- 轮播来源 / 模式 / 间隔：`.rotation.json`
- 桌面一言配置：`.desktop.json`

## 开发

```
pip install class-widgets-sdk>=0.6.0
cw-plugin-pack
```

插件基于 Class Widgets 2 SDK **0.6.0**。
