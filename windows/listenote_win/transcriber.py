from __future__ import annotations

import subprocess
from pathlib import Path

from .simplify import to_simplified_chinese


BLOCKED_HALLUCINATIONS = (
    "请不吝点赞订阅转发打赏支持明镜与点点栏目",
    "明镜需要您的支持 欢迎订阅明镜",
    "中文字幕志愿者 杨茜茜",
)


def clean_text(text: str) -> str:
    compact = "\n".join(line.strip() for line in text.splitlines() if line.strip()).strip()
    if any(phrase in compact for phrase in BLOCKED_HALLUCINATIONS):
        return ""
    return to_simplified_chinese(compact)


class WhisperTranscriber:
    def __init__(self, executable: Path, model: Path, language: str = "zh") -> None:
        self.executable = executable
        self.model = model
        self.language = language

    def transcribe(self, wav_path: Path) -> str:
        if not self.executable.exists():
            raise FileNotFoundError(f"Missing whisper-cli.exe: {self.executable}")
        if not self.model.exists():
            raise FileNotFoundError(f"Missing Whisper model: {self.model}")
        prefix = wav_path.with_suffix("")
        output = prefix.with_suffix(".txt")
        creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        command = [
            str(self.executable), "-m", str(self.model), "-f", str(wav_path),
            "-l", self.language, "-otxt", "-nt", "-np", "-of", str(prefix),
        ]
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=900,
            creationflags=creation_flags,
        )
        if completed.returncode != 0:
            message = completed.stderr.strip() or completed.stdout.strip()
            raise RuntimeError(f"whisper-cli failed ({completed.returncode}): {message[-500:]}")
        if not output.exists():
            raise RuntimeError("whisper-cli did not create a transcript")
        return clean_text(output.read_text(encoding="utf-8-sig", errors="replace"))
