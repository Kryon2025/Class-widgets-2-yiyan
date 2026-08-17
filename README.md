# 每日一言（Class Widgets 2）

Class Widgets 1 版每日一言插件（[cw-yiyan-plugin](https://github.com/laoshuikaixue/cw-yiyan-plugin)，作者 LaoShui）升级到 Class Widgets 2 的版本。

## 功能

- 每天从 `https://api.codelife.cc/yiyan/info?lang=cn` 获取一句话并展示
- 内容超长时自动向上滚动（可设置滚动速度），内容放得下时居中静止显示
- 每日 1 点自动更新
- 请求失败自动重试（3 次，间隔 2 秒），失败后每 5 分钟再试
- 设置页可开关自动滚动、调整滚动速度

## 开发

```
pip install class-widgets-sdk
cw-plugin-pack
```
