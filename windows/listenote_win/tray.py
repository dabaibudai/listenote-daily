from __future__ import annotations

import os
import re
from datetime import datetime
from pathlib import Path
from typing import Callable

import pystray
from PIL import Image, ImageDraw

from .config import load_settings, should_record
from .paths import AppPaths
from .service import ListenoteService

_STATUS_STYLE = {
    "Active": "#16A34A",
    "Processing": "#2563EB",
    "Idle": "#9CA3AF",
    "Error": "#DC2626",
}

_LABELS = {
    "en": {
        "Active": "Recording",
        "Processing": "Processing",
        "Idle": "Idle",
        "Error": "Error",
        "menu_today": "Open Today",
        "menu_notes": "Open Notes",
        "menu_start": "Start Now",
        "menu_stop": "Stop",
        "menu_schedule": "Use Schedule",
        "menu_settings": "Settings",
        "menu_exit": "Exit",
        "detail_active": "{label} {elapsed}",
        "detail_processing": "{label} · {pending} pending",
        "detail_idle_empty": "{label} · no records yet today",
        "detail_idle_stats": "{label} · today {segments} segments · {minutes} min",
    },
    "zh": {
        "Active": "录音中",
        "Processing": "转写中",
        "Idle": "空闲",
        "Error": "出错",
        "menu_today": "打开今日记录",
        "menu_notes": "打开记录文件夹",
        "menu_start": "立即开始",
        "menu_stop": "停止",
        "menu_schedule": "恢复时间表",
        "menu_settings": "设置",
        "menu_exit": "退出",
        "detail_active": "{label} · 已录 {elapsed}",
        "detail_processing": "{label} · 待处理 {pending} 段",
        "detail_idle_empty": "{label} · 今日暂无记录",
        "detail_idle_stats": "{label} · 今日已存 {segments} 段 · {minutes} 分钟",
    },
}


def _fmt_elapsed(seconds: float) -> str:
    total = int(seconds)
    hours, rest = divmod(total, 3600)
    minutes, secs = divmod(rest, 60)
    if hours:
        return f"{hours:d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def _today_stats(paths: AppPaths) -> tuple[int, float]:
    today = paths.notes / f"{datetime.now():%Y-%m-%d}.md"
    segments, seconds = 0, 0.0
    try:
        text = today.read_text(encoding="utf-8", errors="replace")
        segments = sum(1 for line in text.splitlines() if line.startswith("## "))
        for value in re.findall(r"duration=([\d.]+)s", text):
            seconds += float(value)
    except OSError:
        pass
    return segments, seconds


def _study_icon(state: str) -> Image.Image:
    """macOS 同款图标：折角文档 + 状态条，按状态着色。"""
    size = 64
    color = _STATUS_STYLE.get(state, _STATUS_STYLE["Idle"])
    active = state in {"Active", "Processing"}
    s = size / 20.0
    width = max(2, round(1.6 * s))

    def pt(x: float, y: float) -> tuple[float, float]:
        return (x * s, (20.0 - y) * s)  # mac 坐标 y 向上，转为图像 y 向下

    def rect(x: float, y: float, w: float, h: float) -> tuple[float, float, float, float]:
        x0, y0 = pt(x, y + h)
        x1, y1 = pt(x + w, y)
        return (x0, y0, x1, y1)

    def arc(cx: float, cy: float, r: float, start: float, end: float) -> None:
        x0, ya = pt(cx - r, cy - r)
        x1, yb = pt(cx + r, cy + r)
        draw.arc((x0, min(ya, yb), x1, max(ya, yb)), start=start, end=end, fill=color, width=width)

    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # 文档轮廓：上边、右上角斜边、右边、圆角、底边、圆角、左边、圆角
    lw = width / s
    draw.line([pt(5.5, 18.5), pt(11.3, 18.5)], fill=color, width=width)
    draw.line([pt(11.3, 18.5), pt(16.5, 13.3)], fill=color, width=width)
    draw.line([pt(16.5, 13.3), pt(16.5, 3.5)], fill=color, width=width)
    arc(14.5, 3.5, 2.0, 0, 90)
    draw.line([pt(14.5, 1.5), pt(5.5, 1.5)], fill=color, width=width)
    arc(5.5, 3.5, 2.0, 90, 180)
    draw.line([pt(3.5, 3.5), pt(3.5, 16.5)], fill=color, width=width)
    arc(5.5, 16.5, 2.0, 180, 270)
    # 折角内线
    draw.line([pt(11.3, 18.5 - lw), pt(11.3, 14.5)], fill=color, width=width)
    draw.line([pt(11.3, 14.5), pt(12.5, 13.3)], fill=color, width=width)

    # 内部状态条
    if active:
        heights = (4.0, 7.0, 4.0)
        for i, h in enumerate(heights):
            draw.rounded_rectangle(rect(6.3 + i * 2.8, 8.0 - h / 2, 1.8, h), radius=0.9 * s, fill=color)
    else:
        for i in range(2):
            draw.rounded_rectangle(rect(6.8 + i * 4.1, 4.7, 2.3, 6.6), radius=1.15 * s, fill=color)
    return image


class TrayApp:
    def __init__(self, paths: AppPaths) -> None:
        self.paths = paths
        self.service = ListenoteService(paths, self.update_state)
        self.icon = pystray.Icon(
            "ListenoteDaily",
            _study_icon("Idle"),
            "Listenote Daily",
            menu=pystray.Menu(
                pystray.MenuItem(lambda _item: self._status_line(), None, enabled=False),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem(lambda _item: self._text("menu_today"), self.open_today),
                pystray.MenuItem(lambda _item: self._text("menu_notes"), self.open_notes),
                pystray.MenuItem(lambda _item: self._text("menu_start"), self.start_now),
                pystray.MenuItem(lambda _item: self._text("menu_stop"), self.stop_now),
                pystray.MenuItem(lambda _item: self._text("menu_schedule"), self.use_schedule),
                pystray.MenuItem(lambda _item: self._text("menu_settings"), self.open_settings),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem(lambda _item: self._text("menu_exit"), self.exit),
            ),
        )

    def _labels(self) -> dict[str, str]:
        try:
            language = load_settings(self.paths.config).ui_language
        except Exception:
            language = "en"
        return _LABELS.get(language, _LABELS["en"])

    def _text(self, key: str) -> str:
        return self._labels()[key]

    def _status_line(self) -> str:
        labels = self._labels()
        state = self.service.status
        label = labels.get(state, state)
        if state == "Active":
            elapsed = self.service.active_seconds
            if elapsed is not None:
                return labels["detail_active"].format(label=label, elapsed=_fmt_elapsed(elapsed))
            return label
        if state == "Processing":
            pending = self.service.pending_count
            if pending:
                return labels["detail_processing"].format(label=label, pending=pending)
            return label
        segments, seconds = _today_stats(self.paths)
        minutes = int(seconds // 60)
        if segments:
            return labels["detail_idle_stats"].format(label=label, segments=segments, minutes=minutes)
        return labels["detail_idle_empty"].format(label=label)

    def run(self) -> None:
        self.service.start()
        self.icon.run()

    def update_state(self, state: str) -> None:
        if not hasattr(self, "icon"):
            return
        self.icon.icon = _study_icon(state)
        self.icon.title = f"Listenote Daily · {self._labels().get(state, state)}"
        self.icon.update_menu()

    def open_today(self, _icon=None, _item=None) -> None:
        today = self.paths.notes / f"{datetime.now():%Y-%m-%d}.md"
        if today.exists():
            os.startfile(today)
        else:
            self.open_notes()

    def open_notes(self, _icon=None, _item=None) -> None:
        self.paths.notes.mkdir(parents=True, exist_ok=True)
        os.startfile(self.paths.notes)

    def start_now(self, _icon=None, _item=None) -> None:
        self.service.start_manual()

    def stop_now(self, _icon=None, _item=None) -> None:
        self.service.stop_manual()

    def use_schedule(self, _icon=None, _item=None) -> None:
        self.service.use_schedule()

    def open_settings(self, _icon=None, _item=None) -> None:
        load_settings(self.paths.config)
        try:
            from .settings_ui import open_settings_dialog

            open_settings_dialog(self.paths)
        except Exception:
            self.service.log.debug("Settings dialog failed; falling back to editor", exc_info=True)
            os.startfile(self.paths.config)

    def exit(self, _icon=None, _item=None) -> None:
        self.service.shutdown()
        self.icon.stop()
