"""
每日一言
Class Widgets 2 每日一言插件：支持「中文一言 / 英文一言 / 诗词」三种来源轮播，
并可开启桌面一言模式（右上角常驻，可编辑位置/大小/颜色/背景）。

- 组件设置页：来源开关、轮播方式（每节课后 / 自定义间隔）、字体大小与同步主程序字体、
  滚动方式（不滚动 / 纵向 / 横向从右到左）、自定义组件框大小。
- 插件设置页：桌面一言模式（展示类型、字体颜色、背景透明度、编辑窗口）。
"""

from __future__ import annotations

import json
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

from ClassWidgets.SDK import CW2Plugin, PluginAPI
from PySide6.QtCore import Property, QThread, QTimer, QUrl, Qt, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/91.0.4472.124 Safari/537.36"
    )
}

# 来源 id -> (显示名, 接口)
SOURCES = {
    "cn": ("中文一言", "https://api.codelife.cc/yiyan/info?lang=cn"),
    "en": ("英文一言", "https://apiv3.shanbay.com/weapps/dailyquote/quote/"),
    "poem": ("诗词", "https://v1.jinrishici.com/all.json"),
}

_PLUGIN_DIR = Path(__file__).resolve().parent
_DESK_CFG = _PLUGIN_DIR / ".desktop.json"
_ROT_CFG = _PLUGIN_DIR / ".rotation.json"


def _extract(sid, body):
    """把不同来源的响应统一成 {content, author, translation}。"""
    if sid == "poem":
        return {
            "content": body.get("content", "") or "",
            "author": body.get("author") or body.get("origin") or "佚名",
            "translation": "",
        }
    if sid == "en":
        # 扇贝每日一句：英文短句 + 中文翻译 + 作者
        return {
            "content": body.get("content", "") or "",
            "author": body.get("author", "") or "",
            "translation": body.get("translation", "") or "",
        }
    data = body.get("data") or {}
    return {
        "content": data.get("content", "") or "",
        "author": data.get("author", "") or "",
        "translation": "",
    }


class SourceFetchThread(QThread):
    """后台抓取单个来源（最多重试 2 次）。"""

    done = Signal(str, dict)   # sid, {content, author}
    failed = Signal(str)       # sid

    def __init__(self, sid, url, parent=None):
        super().__init__(parent)
        self.sid = sid
        self.url = url
        self.max_retries = 2

    def run(self):
        for _ in range(self.max_retries):
            try:
                req = urllib.request.Request(self.url, headers=HEADERS)
                with urllib.request.urlopen(req, timeout=15) as response:
                    body = json.loads(response.read().decode("utf-8"))
                data = _extract(self.sid, body)
                if data.get("content"):
                    self.done.emit(self.sid, data)
                    return
            except Exception as e:
                print(f"[daily.quote] {self.sid} 请求失败: {e}")
            self.msleep(1500)
        self.failed.emit(self.sid)


class Plugin(CW2Plugin):
    """每日一言小组件 + 桌面一言。"""

    dailyQuoteChanged = Signal()   # 当前来源内容变化
    desktopChanged = Signal()      # 桌面一言配置变化

    def __init__(self, api: PluginAPI):
        super().__init__(api)
        self._src = {sid: {"content": "", "author": "", "translation": "", "status": "idle"} for sid in SOURCES}
        self._active = "cn"
        self._enabled = ["cn"]
        self._mode = "lesson"        # lesson / interval
        self._interval = 300000      # 自定义切换间隔（毫秒）
        self._threads = {}
        self._last_update_date = None
        self._rotate_pending = False   # 轮播待切换：等组件播完本条再切
        self._main_font = ""           # 主程序字体（由组件回传），供桌面一言同步

        self._retry_timer = QTimer(self)
        self._retry_timer.setSingleShot(True)
        self._retry_timer.timeout.connect(self.refresh)

        self._rotate_timer = QTimer(self)
        self._rotate_timer.timeout.connect(self._rotate)

        self._daily_timer = QTimer(self)
        self._daily_timer.setSingleShot(True)
        self._daily_timer.timeout.connect(self.daily_update)
        self._setup_daily_timer()

        # 桌面一言窗口
        self._desk_view = None
        self._desk_on = False
        self._desk_pos = None
        self._desk_cfg = {
            "sources": ["cn"], "fontSize": 20, "fontFamily": "",
            "textColor": "#ffffff", "bgEnabled": False, "bgOpacity": 0.5,
            "w": 380, "h": 160, "edit": False, "showAuthor": True,
            "layer": "bottom",   # top / bottom / normal：桌面一言窗口层级（默认贴桌面）
        }
        self._load_desktop_cfg()
        self._load_rotation_cfg()

        try:
            self.api.runtime.statusChanged.connect(self._on_status_changed)
        except Exception:
            pass

        self.refresh()

    # ── QML 可读属性（当前来源）──────────────────────────────
    def _get_content(self):
        return self._src[self._active]["content"]

    def _get_author(self):
        return self._src[self._active]["author"]

    def _get_translation(self):
        return self._src[self._active].get("translation", "")

    def _get_status(self):
        return self._src[self._active]["status"]

    def _get_active(self):
        return self._active

    dailyQuoteContent = Property(str, _get_content, notify=dailyQuoteChanged)
    dailyQuoteAuthor = Property(str, _get_author, notify=dailyQuoteChanged)
    dailyQuoteTranslation = Property(str, _get_translation, notify=dailyQuoteChanged)
    dailyQuoteStatus = Property(str, _get_status, notify=dailyQuoteChanged)
    dailyQuoteSource = Property(str, _get_active, notify=dailyQuoteChanged)

    # ── 桌面一言属性（供桌面窗口 QML 绑定）────────────────────
    deskQuotesJson = Property(str, lambda s: s._desk_quotes_json(), notify=desktopChanged)
    deskFontSize = Property(int, lambda s: int(s._desk_cfg.get("fontSize", 20)), notify=desktopChanged)
    deskFontFamily = Property(str, lambda s: s._desk_cfg.get("fontFamily", ""), notify=desktopChanged)
    deskTextColor = Property(str, lambda s: s._desk_cfg.get("textColor", "#ffffff"), notify=desktopChanged)
    deskBgEnabled = Property(bool, lambda s: bool(s._desk_cfg.get("bgEnabled", False)), notify=desktopChanged)
    deskBgOpacity = Property(float, lambda s: float(s._desk_cfg.get("bgOpacity", 0.5)), notify=desktopChanged)
    deskEdit = Property(bool, lambda s: bool(s._desk_cfg.get("edit", False)), notify=desktopChanged)
    deskShowAuthor = Property(bool, lambda s: bool(s._desk_cfg.get("showAuthor", True)), notify=desktopChanged)
    deskWidth = Property(int, lambda s: int(s._desk_cfg.get("w", 380)), notify=desktopChanged)
    deskHeight = Property(int, lambda s: int(s._desk_cfg.get("h", 160)), notify=desktopChanged)
    # 主程序「字体」设置项（桌面一言直接同步它）
    mainFontFamily = Property(str, lambda s: s._get_main_font(), notify=desktopChanged)

    # ── 定时器 ──────────────────────────────────────────────
    def _setup_daily_timer(self):
        now = datetime.now()
        nxt = now.replace(hour=1, minute=0, second=0, microsecond=0)
        if now >= nxt:
            nxt += timedelta(days=1)
        self._daily_timer.start(int((nxt - now).total_seconds() * 1000))

    def daily_update(self):
        if self._last_update_date != datetime.now().date():
            self.refresh()
        self._setup_daily_timer()

    # ── 抓取 ────────────────────────────────────────────────
    def _needed_sources(self):
        """需要抓取的来源 = 组件轮播来源 ∪ 桌面一言来源。

        两者各自独立选择来源。如果只抓 self._enabled，桌面一言勾选的
        英文/诗词就永远没有内容，_desk_quotes_json 会把空内容过滤掉，
        结果桌面只剩中文一言。
        """
        need = set(self._enabled)
        if self._desk_on:
            need |= set(self._desk_cfg.get("sources") or ["cn"])
        return [sid for sid in SOURCES if sid in need]

    @Slot()
    def refresh(self):
        for sid in self._needed_sources():
            self._fetch(sid)

    def _fetch_missing(self):
        """只为还没有内容的来源发起抓取（桌面新增来源时用，避免重复请求）。"""
        for sid in self._needed_sources():
            if not self._src[sid].get("content"):
                self._fetch(sid)

    def _fetch(self, sid):
        t = self._threads.get(sid)
        if t and t.isRunning():
            return
        if not self._src[sid]["content"]:
            self._src[sid]["status"] = "loading"
        if sid == self._active:
            self.dailyQuoteChanged.emit()
        self._retry_timer.stop()
        thread = SourceFetchThread(sid, SOURCES[sid][1], self)
        thread.done.connect(self._on_success)
        thread.failed.connect(self._on_failure)
        thread.finished.connect(lambda s=sid: self._cleanup_thread(s))
        self._threads[sid] = thread
        thread.start()

    def _cleanup_thread(self, sid):
        t = self._threads.pop(sid, None)
        if t:
            t.deleteLater()

    def _on_success(self, sid, data):
        self._src[sid]["content"] = data.get("content", "")
        self._src[sid]["author"] = data.get("author", "")
        self._src[sid]["translation"] = data.get("translation", "")
        self._src[sid]["status"] = "ok"
        self._last_update_date = datetime.now().date()
        if sid == self._active:
            self.dailyQuoteChanged.emit()
        self.desktopChanged.emit()
        print(f"[daily.quote] {sid} 更新成功: {self._src[sid]['author']}")

    def _on_failure(self, sid):
        if not self._src[sid]["content"]:
            self._src[sid]["status"] = "error"
        if sid == self._active:
            self.dailyQuoteChanged.emit()
        print(f"[daily.quote] {sid} 抓取失败，5 分钟后重试")
        self._retry_timer.start(5 * 60 * 1000)

    # ── 来源轮播 ────────────────────────────────────────────
    @Slot(result="QVariantList")
    def enabledSources(self):
        """当前启用的来源列表（供 QML 比较，避免重复同步）。"""
        return list(self._enabled)

    @Slot(list, str, int)
    def setRotationConfig(self, enabled, mode, interval):
        en = [s for s in (enabled or []) if s in SOURCES]
        self._enabled = en or ["cn"]
        self._mode = mode if mode in ("interval", "lesson") else "lesson"
        self._interval = max(3000, int(interval or 300000))
        if self._active not in self._enabled:
            self._active = self._enabled[0]
            self.dailyQuoteChanged.emit()
        self._update_rotate_timer()
        self._save_rotation_cfg()
        self.refresh()

    def _set_active(self, sid):
        if sid == self._active:
            return
        self._active = sid
        self.dailyQuoteChanged.emit()

    @Slot(str)
    def setActiveSource(self, sid):
        """设置页打开某来源时立即切换到它展示，不等待轮播时机。

        用户「打开英文/诗词」后立刻看到它（抓取中→内容），而不是等下一节课。
        容错：即使此刻轮播配置还没同步到该来源，也把它纳入启用列表并切换，
        避免"勾选了却始终显示中文"。
        """
        if sid not in SOURCES:
            return
        if sid not in self._enabled:
            self._enabled.append(sid)
            self._update_rotate_timer()
        if sid != self._active:
            self._set_active(sid)
        self._fetch(sid)
        print(f"[daily.quote] 切换到来源: {SOURCES[sid][0]}")

    def _rotate(self):
        """轮播定时到点：只标记待切换，等组件报告「本条播放完毕」再真正切换。"""
        if len(self._enabled) <= 1:
            return
        self._rotate_pending = True

    @Slot()
    def onQuotePlaybackFinished(self):
        """QML 每播完一条（滚完一轮 / 静止展示一段）调用一次。

        有轮播待切换时在此刻切换，保证「当前一言播放完毕后」才切下一条。
        """
        if not self._rotate_pending:
            return
        self._rotate_pending = False
        if len(self._enabled) <= 1:
            return
        i = self._enabled.index(self._active) if self._active in self._enabled else -1
        nxt = self._enabled[(i + 1) % len(self._enabled)]
        self._set_active(nxt)
        self._fetch(nxt)          # 切换时刷新，展示新的句子
        self.desktopChanged.emit()

    def _update_rotate_timer(self):
        if self._mode == "interval" and len(self._enabled) > 1:
            self._rotate_timer.start(self._interval)
        else:
            self._rotate_timer.stop()

    def _on_status_changed(self, *args):
        """下课/放学边界切换来源（轮播方式 = 每节课后）。"""
        try:
            status = args[0] if args else None
            if self._mode == "lesson" and status in ("break", "free", "activity"):
                self._rotate()
        except Exception:
            pass

    # ── 桌面一言 ────────────────────────────────────────────
    def _desk_quotes_json(self):
        out = []
        for sid in self._desk_cfg.get("sources", []):
            st = self._src.get(sid)
            if st and st.get("content"):
                out.append({"source": SOURCES[sid][0], "content": st["content"],
                            "author": st["author"], "translation": st.get("translation", "")})
        return json.dumps(out, ensure_ascii=False)

    def _load_desktop_cfg(self):
        try:
            if _DESK_CFG.is_file():
                cfg = json.loads(_DESK_CFG.read_text(encoding="utf-8"))
                if isinstance(cfg, dict):
                    self._desk_on = bool(cfg.get("enabled", False))
                    for k, v in (cfg.get("config") or {}).items():
                        self._desk_cfg[k] = v
                    pos = cfg.get("pos")
                    if isinstance(pos, list) and len(pos) == 2:
                        self._desk_pos = [int(pos[0]), int(pos[1])]
        except Exception as e:
            print(f"[daily.quote] 读取桌面配置失败: {e}")

    def _save_desktop_cfg(self):
        try:
            _DESK_CFG.write_text(json.dumps({
                "enabled": self._desk_on,
                "config": self._desk_cfg,
                "pos": self._desk_pos,
            }, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[daily.quote] 保存桌面配置失败: {e}")

    def _load_rotation_cfg(self):
        """启动时读回用户保存的轮播来源，避免「设置英文却播中文」。"""
        try:
            if _ROT_CFG.is_file():
                cfg = json.loads(_ROT_CFG.read_text(encoding="utf-8"))
                if isinstance(cfg, dict):
                    en = [s for s in (cfg.get("sources") or []) if s in SOURCES]
                    if en:
                        self._enabled = en
                        if self._active not in en:
                            self._active = en[0]
                    if cfg.get("mode") in ("lesson", "interval"):
                        self._mode = cfg["mode"]
                    self._interval = max(3000, int(cfg.get("interval") or 300000))
        except Exception as e:
            print(f"[daily.quote] 读取轮播配置失败: {e}")

    def _save_rotation_cfg(self):
        try:
            _ROT_CFG.write_text(json.dumps({
                "sources": self._enabled,
                "mode": self._mode,
                "interval": self._interval,
            }, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"[daily.quote] 保存轮播配置失败: {e}")

    @Slot(bool)
    def setDesktopEnabled(self, on):
        self._desk_on = bool(on)
        self._desk_cfg["edit"] = False
        self._save_desktop_cfg()
        self._fetch_missing()      # 桌面来源可能还没被抓取过
        self._sync_desktop()
        self.desktopChanged.emit()

    @Slot(str)
    def setDesktopConfigJson(self, js):
        try:
            cfg = json.loads(js or "{}")
            if isinstance(cfg, dict):
                self._desk_cfg.update(cfg)
        except Exception as e:
            print(f"[daily.quote] 桌面配置解析失败: {e}")
        self._save_desktop_cfg()
        self._fetch_missing()      # 新勾选的来源需要立刻抓取
        self._sync_desktop()
        self.desktopChanged.emit()

    @Slot(bool)
    def setDesktopEditMode(self, on):
        self._desk_cfg["edit"] = bool(on)
        self._save_desktop_cfg()
        self.desktopChanged.emit()

    @Slot(int, int)
    def moveDesktopBy(self, dx, dy):
        if self._desk_view:
            self._desk_pos = [self._desk_view.x() + int(dx), self._desk_view.y() + int(dy)]
            self._desk_view.setX(self._desk_pos[0])
            self._desk_view.setY(self._desk_pos[1])

    @Slot()
    def resetDesktopPos(self):
        """把桌面一言窗口重置回右上角（清除已保存位置）。"""
        self._desk_pos = None
        self._save_desktop_cfg()
        self._sync_desktop()
        self.desktopChanged.emit()

    @Slot(str)
    def setMainFont(self, family):
        """组件把「主程序字体」回传进来（读不到主程序配置时的兜底）。"""
        family = family or ""
        if family != self._main_font:
            self._main_font = family
            self.desktopChanged.emit()

    def _get_main_font(self):
        """主程序「字体」设置项：读到就用它，否则回退到组件回传的字体。"""
        try:
            f = self.api.globalconfig.configs.preferences.font
            if f:
                return str(f)
        except Exception:
            pass
        return self._main_font

    @Slot(int, int)
    def resizeDesktop(self, w, h):
        self._desk_cfg["w"] = max(160, int(w))
        self._desk_cfg["h"] = max(60, int(h))
        if self._desk_view:
            self._desk_view.setWidth(self._desk_cfg["w"])
            self._desk_view.setHeight(self._desk_cfg["h"])
        self._save_desktop_cfg()
        self.desktopChanged.emit()

    @Slot()
    def confirmDesktopEdit(self):
        self._desk_cfg["edit"] = False
        self._save_desktop_cfg()
        self._sync_desktop()
        self.desktopChanged.emit()

    @Slot(result=str)
    def getDesktopConfigJson(self):
        return json.dumps({"enabled": self._desk_on, "config": self._desk_cfg}, ensure_ascii=False)

    def _ensure_desk_view(self):
        if self._desk_view is not None:
            return self._desk_view
        qml = _PLUGIN_DIR / "qml" / "daily-quote-desktop.qml"
        try:
            view = QQuickView()
            # 初始不带置顶/置底 flag，统一由 _sync_desktop 按 layer 配置设置，
            # 避免窗口创建瞬间短暂置顶再被按下造成闪烁
            view.setFlags(Qt.FramelessWindowHint | Qt.Tool)
            view.setColor(Qt.transparent)
            view.setResizeMode(QQuickView.SizeRootObjectToView)
            view.rootContext().setContextProperty("quoteBackend", self)
            view.setSource(QUrl.fromLocalFile(str(qml)))
            self._desk_view = view
        except Exception as e:
            print(f"[daily.quote] 创建桌面窗口失败: {e}")
            self._desk_view = None
        return self._desk_view

    def _sync_desktop(self):
        if not self._desk_on:
            if self._desk_view:
                self._desk_view.hide()
            return
        view = self._ensure_desk_view()
        if view is None:
            return
        try:
            w = int(self._desk_cfg.get("w", 380))
            h = int(self._desk_cfg.get("h", 160))
            view.setWidth(w)
            view.setHeight(h)
            if self._desk_pos is None:
                scr = QGuiApplication.primaryScreen()
                geo = scr.availableGeometry()
                self._desk_pos = [int(geo.right() - w - 24), int(geo.top() + 24)]
            view.setX(self._desk_pos[0])
            view.setY(self._desk_pos[1])
            # 按用户选择的层级显式设置窗口 flag，避免 Qt.Tool 无父窗口时层级漂移
            # （平时被压到下面、编辑后又冒到顶上）。每次同步都重设，保证编辑
            # 结束、重新显示后层级与平时一致。
            layer = self._desk_cfg.get("layer", "bottom")
            view.setFlag(Qt.WindowStaysOnTopHint, layer == "top")
            view.setFlag(Qt.WindowStaysOnBottomHint, layer == "bottom")
            view.show()
            if layer == "bottom":
                view.lower()
            else:
                view.raise_()
        except Exception as e:
            print(f"[daily.quote] 显示桌面窗口失败: {e}")

    # ── 生命周期 ────────────────────────────────────────────
    def on_load(self):
        super().on_load()
        self.api.widgets.register(
            widget_id="com.daily.quote.component",
            name="每日一言",
            qml_path="qml/daily-quote.qml",
            backend_obj=self,
            settings_qml="qml/daily-quote-settings.qml",
            default_settings={
                "auto_scroll": True,       # 纵向滚动
                "scroll_speed": 40,        # 滚动速度（像素/秒）
                "scroll_pause": 1200,      # 每轮停留（毫秒）
                "scroll_mode": "auto",     # auto / none / hscroll
                "font_size": 16,           # 正文字号（px）
                "translation_font_size": 0,  # 译文字号（px，0 = 按正文字号自动推算）
                "translation_after": True,   # 英文一言：先播完原文再播译文（否则原文/译文双行同屏）
                "sync_main_font": True,    # 同步主程序字体
                "font_family": "",         # 自定义字体（不同步时生效）
                "box_width": 0,            # 自定义宽（0 = 默认 380）
                "box_height": 0,           # 自定义高（0 = 默认）
                "sources": ["cn"],         # 启用的来源
                "switch_mode": "lesson",   # lesson / interval
                "switch_interval": 300000, # 自定义切换间隔（毫秒）
            },
        )

        try:
            settings_qml = str(_PLUGIN_DIR / "qml" / "daily-quote-plugin-settings.qml")
            self.api.ui.register_settings_page(
                qml_path=settings_qml,
                title="每日一言",
                icon="ic_fluent_text_quote_20_regular",
            )
        except Exception as e:
            print(f"[daily.quote] 注册插件设置页失败: {e}")

        if self._desk_on:
            self._sync_desktop()
        # 启动即抓取：构造期发起的那次可能早于运行时/组件就绪，这里补一次（幂等）
        self.refresh()
        print("[daily.quote] 插件已加载")

    def on_unload(self):
        self._retry_timer.stop()
        self._daily_timer.stop()
        self._rotate_timer.stop()
        try:
            self.api.runtime.statusChanged.disconnect(self._on_status_changed)
        except Exception:
            pass
        for sid, t in list(self._threads.items()):
            try:
                t.requestInterruption()
                if t.isRunning():
                    t.wait(15000)
            except Exception:
                pass
        self._threads.clear()
        if self._desk_view:
            try:
                self._desk_view.hide()
                self._desk_view.deleteLater()
            except Exception:
                pass
            self._desk_view = None
        print("[daily.quote] 插件已卸载")
