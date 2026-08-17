"""
每日一言
Class Widgets 2 每日一言插件，每天从 api.codelife.cc 获取一句话。
"""

import json
import urllib.request
from datetime import datetime, timedelta

from ClassWidgets.SDK import CW2Plugin, PluginAPI
from PySide6.QtCore import QThread, Signal, Property, Slot, QTimer

API_URL = "https://api.codelife.cc/yiyan/info?lang=cn"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/91.0.4472.124 Safari/537.36"
    )
}


class FetchThread(QThread):
    """后台抓取线程（最多重试 3 次，间隔 2 秒）"""

    fetch_finished = Signal(dict)
    fetch_failed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.max_retries = 3

    def run(self):
        retry_count = 0
        while retry_count < self.max_retries:
            try:
                request = urllib.request.Request(API_URL, headers=HEADERS)
                with urllib.request.urlopen(request, timeout=15) as response:
                    body = json.loads(response.read().decode("utf-8"))
                data = body.get("data") or {}
                if data.get("content"):
                    self.fetch_finished.emit(data)
                    return
            except Exception as e:
                print(f"[daily.quote] 请求失败: {e}")
            retry_count += 1
            self.msleep(2000)
        self.fetch_failed.emit()


class Plugin(CW2Plugin):
    """每日一言小组件"""

    # 内容/作者/状态任一变化都会通知 QML
    dailyQuoteChanged = Signal()

    def __init__(self, api: PluginAPI):
        super().__init__(api)
        self._content = ""
        self._author = ""
        self._status = "loading"  # loading / ok / error
        self._fetch_thread = None
        self._last_update_date = None

        # 失败后 5 分钟自动重试
        self._retry_timer = QTimer(self)
        self._retry_timer.setSingleShot(True)
        self._retry_timer.timeout.connect(self.refresh)

        # 每日 1 点自动更新
        self._daily_timer = QTimer(self)
        self._daily_timer.setSingleShot(True)
        self._daily_timer.timeout.connect(self.daily_update)
        self._setup_daily_timer()

        # 插件加载后立即抓取一次
        self.refresh()

    # ---- QML 可读属性 ----
    def _get_content(self):
        return self._content

    def _get_author(self):
        return self._author

    def _get_status(self):
        return self._status

    dailyQuoteContent = Property(str, _get_content, notify=dailyQuoteChanged)
    dailyQuoteAuthor = Property(str, _get_author, notify=dailyQuoteChanged)
    dailyQuoteStatus = Property(str, _get_status, notify=dailyQuoteChanged)

    def _setup_daily_timer(self):
        """计算并启动下一次 1 点的单次定时器"""
        now = datetime.now()
        next_update = now.replace(hour=1, minute=0, second=0, microsecond=0)
        if now >= next_update:
            next_update += timedelta(days=1)
        self._daily_timer.start(int((next_update - now).total_seconds() * 1000))
        print(f"[daily.quote] 下次自动更新: {next_update.strftime('%Y-%m-%d %H:%M:%S')}")

    def daily_update(self):
        """每日 1 点触发"""
        if self._last_update_date != datetime.now().date():
            self.refresh()
        self._setup_daily_timer()

    @Slot()
    def refresh(self):
        """开始异步抓取每日一言"""
        self._status = "loading"
        self.dailyQuoteChanged.emit()
        self._retry_timer.stop()

        if self._fetch_thread and self._fetch_thread.isRunning():
            return  # 已有请求在进行中

        self._fetch_thread = FetchThread(self)
        self._fetch_thread.fetch_finished.connect(self._on_success)
        self._fetch_thread.fetch_failed.connect(self._on_failure)
        self._fetch_thread.start()

    def _on_success(self, data):
        self._content = data.get("content", "无法获取一言信息。")
        self._author = data.get("author", "未知作者")
        self._status = "ok"
        self._last_update_date = datetime.now().date()
        self.dailyQuoteChanged.emit()
        print(f"[daily.quote] 更新成功: {self._author}")

    def _on_failure(self):
        print("[daily.quote] 重试3次失败，5分钟后自动重试")
        self._content = ""
        self._author = ""
        self._status = "error"
        self.dailyQuoteChanged.emit()
        self._retry_timer.start(5 * 60 * 1000)

    def on_load(self):
        super().on_load()
        self.api.widgets.register(
            widget_id="com.daily.quote.component",
            name="每日一言",
            qml_path="qml/daily-quote.qml",
            backend_obj=self,
            settings_qml="qml/daily-quote-settings.qml",
            default_settings={
                "auto_scroll": True,  # 内容超长时自动滚动
                "scroll_speed": 20,   # 滚动速度（像素/秒），默认较慢
                "scroll_pause": 1200, # 每轮循环结束后的停留时间（毫秒）
            },
        )
        print("[daily.quote] 插件已加载")

    def on_unload(self):
        self._retry_timer.stop()
        self._daily_timer.stop()
        if self._fetch_thread and self._fetch_thread.isRunning():
            self._fetch_thread.quit()
            self._fetch_thread.wait(2000)
        print("[daily.quote] 插件已卸载")
