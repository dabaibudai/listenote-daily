from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AppPaths:
    root: Path
    config: Path
    notes: Path
    temp: Path
    logs: Path
    whisper_exe: Path
    model: Path

    @classmethod
    def discover(cls) -> "AppPaths":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        root = Path(os.environ.get("LISTENOTE_DAILY_ROOT", base / "Listenote Daily"))
        return cls(
            root=root,
            config=root / "config.ini",
            notes=root / "records" / "transcripts",
            temp=root / "temp",
            logs=root / "logs",
            whisper_exe=root / "tools" / "whisper" / "whisper-cli.exe",
            model=root / "models" / "ggml-large-v3-turbo.bin",
        )

    def ensure_directories(self) -> None:
        for path in (self.root, self.notes, self.temp, self.logs, self.model.parent):
            path.mkdir(parents=True, exist_ok=True)
