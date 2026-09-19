from __future__ import annotations

import configparser
import io
from pathlib import Path

from .config import load_settings, parse_windows
from .paths import AppPaths

_TEXT = {
    "en": {
        "title": "Listenote Daily Settings",
        "schedule": "Schedule",
        "enabled": "Enable automatic schedule",
        "days": "Days",
        "day_names": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        "windows": "Time windows (comma separated, e.g. 09:00-12:00,13:30-18:00)",
        "transcription": "Transcription",
        "language": "Speech language (e.g. zh, en, ja)",
        "chunk_seconds": "Chunk length (seconds, 10-600)",
        "minimum_rms": "Minimum volume threshold (RMS)",
        "model": "Model file (relative path)",
        "ui_language": "Tray menu language",
        "save": "Save",
        "cancel": "Cancel",
        "saved": "Saved. Takes effect within seconds, no restart needed.",
        "invalid": "Invalid settings",
    },
    "zh": {
        "title": "Listenote Daily 设置",
        "schedule": "录音时间表",
        "enabled": "启用自动时间表",
        "days": "星期",
        "day_names": ["一", "二", "三", "四", "五", "六", "日"],
        "windows": "时间段（英文逗号分隔，如 09:00-12:00,13:30-18:00）",
        "chunk_seconds": "分段长度（秒，10–600）",
        "minimum_rms": "最小音量阈值（RMS）",
        "language": "转写语言（如 zh、en、ja）",
        "model": "模型文件（相对路径）",
        "ui_language": "托盘菜单语言",
        "save": "保存",
        "cancel": "取消",
        "saved": "已保存，数秒内自动生效，无需重启。",
        "invalid": "设置不合法",
    },
}


def open_settings_dialog(paths: AppPaths) -> bool:
    """Open a small settings window. Returns True when the dialog was shown."""
    import tkinter as tk
    from tkinter import messagebox, ttk

    settings = load_settings(paths.config)
    lang = getattr(settings, "ui_language", "en")
    t = _TEXT.get(lang, _TEXT["en"])

    root = tk.Toplevel()
    root.title(t["title"])
    root.resizable(False, False)
    root.grab_set()
    frame = ttk.Frame(root, padding=14)
    frame.grid(sticky="nsew")

    enabled_var = tk.BooleanVar(value=settings.enabled)
    day_vars = [tk.BooleanVar(value=(i + 1) in settings.days) for i in range(7)]
    windows_var = tk.StringVar(
        value=",".join(
            f"{w.start // 60:02d}:{w.start % 60:02d}-{w.end // 60:02d}:{w.end % 60:02d}"
            for w in settings.windows
        )
    )
    language_var = tk.StringVar(value=settings.language)
    chunk_var = tk.StringVar(value=str(settings.chunk_seconds))
    rms_var = tk.StringVar(value=str(settings.minimum_rms))
    model_var = tk.StringVar(value=str(settings.model_relative))
    ui_var = tk.StringVar(value=lang)

    row = 0
    ttk.Label(frame, text=t["schedule"], font=("", 10, "bold")).grid(row=row, column=0, sticky="w", pady=(0, 4))
    row += 1
    ttk.Checkbutton(frame, text=t["enabled"], variable=enabled_var).grid(row=row, column=0, columnspan=3, sticky="w")
    row += 1
    ttk.Label(frame, text=t["days"]).grid(row=row, column=0, sticky="w")
    for i, name in enumerate(t["day_names"]):
        ttk.Checkbutton(frame, text=name, variable=day_vars[i]).grid(row=row, column=1 + i % 4, sticky="w")
        if i % 4 == 3:
            row += 1
    if 7 % 4:
        row += 1
    ttk.Label(frame, text=t["windows"]).grid(row=row, column=0, sticky="w")
    ttk.Entry(frame, textvariable=windows_var, width=42).grid(row=row, column=1, columnspan=4, sticky="we", pady=2)
    row += 2

    ttk.Label(frame, text=t["transcription"], font=("", 10, "bold")).grid(row=row, column=0, sticky="w", pady=(6, 4))
    row += 1
    ttk.Label(frame, text=t["language"]).grid(row=row, column=0, sticky="w")
    ttk.Entry(frame, textvariable=language_var, width=12).grid(row=row, column=1, sticky="w", pady=2)
    row += 1
    ttk.Label(frame, text=t["chunk_seconds"]).grid(row=row, column=0, sticky="w")
    ttk.Entry(frame, textvariable=chunk_var, width=12).grid(row=row, column=1, sticky="w", pady=2)
    row += 1
    ttk.Label(frame, text=t["minimum_rms"]).grid(row=row, column=0, sticky="w")
    ttk.Entry(frame, textvariable=rms_var, width=12).grid(row=row, column=1, sticky="w", pady=2)
    row += 1
    ttk.Label(frame, text=t["model"]).grid(row=row, column=0, sticky="w")
    ttk.Entry(frame, textvariable=model_var, width=42).grid(row=row, column=1, columnspan=4, sticky="we", pady=2)
    row += 1
    ttk.Label(frame, text=t["ui_language"]).grid(row=row, column=0, sticky="w")
    ttk.Combobox(frame, textvariable=ui_var, values=["zh", "en"], width=10, state="readonly").grid(row=row, column=1, sticky="w", pady=2)
    row += 2

    result = {"saved": False}

    def save() -> None:
        days = ",".join(str(i + 1) for i, var in enumerate(day_vars) if var.get())
        text = (
            "[schedule]\n"
            f"enabled = {'true' if enabled_var.get() else 'false'}\n"
            f"days = {days}\n"
            f"windows = {windows_var.get().strip()}\n"
            "\n[transcription]\n"
            f"language = {language_var.get().strip() or 'zh'}\n"
            f"chunk_seconds = {chunk_var.get().strip() or '60'}\n"
            f"minimum_rms = {rms_var.get().strip() or '220'}\n"
            f"model = {model_var.get().strip() or r'models\\ggml-large-v3-turbo.bin'}\n"
            "\n[ui]\n"
            f"language = {ui_var.get().strip() or 'en'}\n"
        )
        try:
            parser = configparser.ConfigParser()
            parser.read_file(io.StringIO(text))
            parse_windows(parser["schedule"]["windows"])
            chunk = parser.getint("transcription", "chunk_seconds")
            rms = parser.getint("transcription", "minimum_rms")
            if not 10 <= chunk <= 600:
                raise ValueError("chunk_seconds must be between 10 and 600")
            if rms < 0:
                raise ValueError("minimum_rms cannot be negative")
            if not days:
                raise ValueError("at least one day must be selected")
            if parser.get("ui", "language") not in {"en", "zh"}:
                raise ValueError("ui language must be 'en' or 'zh'")
        except (ValueError, configparser.Error) as exc:
            messagebox.showerror(t["invalid"], str(exc), parent=root)
            return
        paths.config.write_text(text, encoding="utf-8")
        result["saved"] = True
        messagebox.showinfo(t["title"], t["saved"], parent=root)
        root.destroy()

    ttk.Button(frame, text=t["save"], command=save).grid(row=row, column=1, sticky="e", padx=(0, 6))
    ttk.Button(frame, text=t["cancel"], command=root.destroy).grid(row=row, column=2, sticky="w")
    root.update_idletasks()
    root.mainloop()
    return True
