import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import patch

from listenote_win.config import Settings, TimeWindow
from listenote_win.paths import AppPaths
from listenote_win.service import ListenoteService, PendingChunk


class ServiceTests(unittest.TestCase):
    def make_paths(self, root: Path) -> AppPaths:
        return AppPaths(
            root=root,
            config=root / "config.ini",
            notes=root / "records" / "transcripts",
            temp=root / "temp",
            logs=root / "logs",
            whisper_exe=root / "tools" / "whisper-cli.exe",
            model=root / "models" / "model.bin",
        )

    def test_stale_audio_is_deleted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = self.make_paths(root)
            paths.ensure_directories()
            stale = paths.temp / "chunk-old.wav"
            stale.write_bytes(b"temporary")
            ListenoteService(paths)._cleanup_stale_temp()
            self.assertFalse(stale.exists())

    def test_worker_writes_markdown_and_deletes_audio(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = self.make_paths(Path(directory))
            paths.ensure_directories()
            wav = paths.temp / "chunk-test.wav"
            wav.write_bytes(b"audio")
            started = datetime(2026, 9, 13, 10, 0, 0)
            settings = Settings(True, frozenset({7}), (TimeWindow(0, 1),), "zh", 60, 0, Path("models/model.bin"), "en")
            service = ListenoteService(paths)
            service._queue.put(PendingChunk(wav, started, started + timedelta(seconds=60), settings))
            service._queue.put(None)
            with patch("listenote_win.service.WhisperTranscriber.transcribe", return_value="测试内容"):
                service._transcription_loop()
            self.assertFalse(wav.exists())
            self.assertIn("测试内容", (paths.notes / "2026-09-13.md").read_text(encoding="utf-8"))

    def test_worker_deletes_audio_after_transcription_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = self.make_paths(Path(directory))
            paths.ensure_directories()
            wav = paths.temp / "chunk-failed.wav"
            wav.write_bytes(b"audio")
            started = datetime(2026, 9, 13, 10, 0, 0)
            settings = Settings(True, frozenset({7}), (TimeWindow(0, 1),), "zh", 60, 0, Path("models/model.bin"), "en")
            service = ListenoteService(paths)
            service._queue.put(PendingChunk(wav, started, started + timedelta(seconds=60), settings))
            service._queue.put(None)
            with self.assertLogs("listenote", level="ERROR"):
                with patch("listenote_win.service.WhisperTranscriber.transcribe", side_effect=RuntimeError("failed")):
                    service._transcription_loop()
            self.assertFalse(wav.exists())


if __name__ == "__main__":
    unittest.main()
