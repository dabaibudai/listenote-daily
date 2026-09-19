from __future__ import annotations

import configparser
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


DEFAULT_CONFIG = """[schedule]
enabled = true
days = 1,2,3,4,5,6,7
windows = 09:00-12:00,13:30-18:00

[transcription]
language = zh
chunk_seconds = 60
minimum_rms = 220
model = models\\ggml-large-v3-turbo.bin
"""


@dataclass(frozen=True)
class TimeWindow:
    start: int
    end: int

    def contains(self, minute: int) -> bool:
        if self.start < self.end:
            return self.start <= minute < self.end
        return minute >= self.start or minute < self.end


@dataclass(frozen=True)
class Settings:
    enabled: bool
    days: frozenset[int]
    windows: tuple[TimeWindow, ...]
    language: str
    chunk_seconds: int
    minimum_rms: int
    model_relative: Path
    ui_language: str


def _minute(value: str) -> int:
    hour_text, minute_text = value.strip().split(":", 1)
    hour, minute = int(hour_text), int(minute_text)
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        raise ValueError(f"Invalid time: {value}")
    return hour * 60 + minute


def parse_windows(value: str) -> tuple[TimeWindow, ...]:
    windows: list[TimeWindow] = []
    for raw in filter(None, (part.strip() for part in value.split(","))):
        start, end = raw.split("-", 1)
        parsed = TimeWindow(_minute(start), _minute(end))
        if parsed.start == parsed.end:
            raise ValueError("A schedule window cannot be zero length")
        windows.append(parsed)
    if not windows:
        raise ValueError("At least one schedule window is required")
    return tuple(windows)


def ensure_config(path: Path) -> None:
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(DEFAULT_CONFIG, encoding="utf-8")


def load_settings(path: Path) -> Settings:
    ensure_config(path)
    parser = configparser.ConfigParser()
    with path.open("r", encoding="utf-8-sig") as handle:
        parser.read_file(handle)
    days = frozenset(int(item.strip()) for item in parser["schedule"]["days"].split(","))
    if not days or any(day < 1 or day > 7 for day in days):
        raise ValueError("Schedule days must be ISO weekday values 1 through 7")
    chunk_seconds = parser.getint("transcription", "chunk_seconds", fallback=60)
    minimum_rms = parser.getint("transcription", "minimum_rms", fallback=220)
    if not 10 <= chunk_seconds <= 600:
        raise ValueError("chunk_seconds must be between 10 and 600")
    if minimum_rms < 0:
        raise ValueError("minimum_rms cannot be negative")
    ui_language = parser.get("ui", "language", fallback="en").strip().lower()
    if ui_language not in {"en", "zh"}:
        raise ValueError("ui language must be 'en' or 'zh'")
    return Settings(
        enabled=parser.getboolean("schedule", "enabled", fallback=True),
        days=days,
        windows=parse_windows(parser["schedule"]["windows"]),
        language=parser.get("transcription", "language", fallback="zh"),
        chunk_seconds=chunk_seconds,
        minimum_rms=minimum_rms,
        model_relative=Path(parser.get("transcription", "model", fallback=r"models\ggml-large-v3-turbo.bin")),
        ui_language=ui_language,
    )


def should_record(now: datetime, settings: Settings) -> bool:
    if not settings.enabled or now.isoweekday() not in settings.days:
        return False
    minute = now.hour * 60 + now.minute
    return any(window.contains(minute) for window in settings.windows)
