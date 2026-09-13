from __future__ import annotations

import os
from datetime import datetime
from pathlib import Path
from typing import Callable

import pystray
from PIL import Image, ImageDraw

from .config import load_settings, should_record
from .paths import AppPaths
from .service import ListenoteService


def _study_icon(active: bool) -> Image.Image:
    size = 64
    color = "#2563EB" if active else "#6B7280"
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((25, 7, 39, 21), fill=color)
    draw.rounded_rectangle((20, 22, 44, 46), radius=10, fill=color)
    draw.polygon([(5, 34), (29, 40), (29, 57), (5, 50)], fill="white", outline=color, width=3)
    draw.polygon([(59, 34), (35, 40), (35, 57), (59, 50)], fill="white", outline=color, width=3)
    draw.line((32, 39, 32, 58), fill=color, width=3)
    return image


class TrayApp:
    def __init__(self, paths: AppPaths) -> None:
        self.paths = paths
        self.service = ListenoteService(paths, self.update_state)
        self.icon = pystray.Icon(
            "ListenoteDaily",
            _study_icon(False),
            "Listenote Daily • Idle",
            menu=pystray.Menu(
                pystray.MenuItem(lambda _item: f"Status: {self.service.status}", None, enabled=False),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Open Today", self.open_today),
                pystray.MenuItem("Open Notes", self.open_notes),
                pystray.MenuItem("Start Now", self.start_now),
                pystray.MenuItem("Stop", self.stop_now),
                pystray.MenuItem("Use Schedule", self.use_schedule),
                pystray.MenuItem("Settings", self.open_settings),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Exit", self.exit),
            ),
        )

    def run(self) -> None:
        self.service.start()
        self.icon.run()

    def update_state(self, state: str) -> None:
        if not hasattr(self, "icon"):
            return
        active = state in {"Active", "Processing"}
        self.icon.icon = _study_icon(active)
        self.icon.title = f"Listenote Daily • {state}"
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
        os.startfile(self.paths.config)

    def exit(self, _icon=None, _item=None) -> None:
        self.service.shutdown()
        self.icon.stop()
