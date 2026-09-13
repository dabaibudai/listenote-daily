from __future__ import annotations

from datetime import datetime
from pathlib import Path


def append_transcript(notes_dir: Path, started: datetime, ended: datetime, text: str, model: str) -> Path:
    notes_dir.mkdir(parents=True, exist_ok=True)
    output = notes_dir / f"{started:%Y-%m-%d}.md"
    if not output.exists():
        output.write_text(f"# {started:%Y-%m-%d}\n\n", encoding="utf-8")
    duration = max(0.0, (ended - started).total_seconds())
    block = (
        f"## {started:%H:%M:%S}–{ended:%H:%M:%S}\n\n"
        f"<!-- model={model}; language=zh; duration={duration:.1f}s -->\n\n"
        f"{text.strip()}\n\n"
    )
    with output.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(block)
    return output
