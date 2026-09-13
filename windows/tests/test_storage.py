import tempfile
import unittest
import wave
import os
from datetime import datetime
from pathlib import Path

from listenote_win.audio import pcm_rms
from listenote_win.storage import append_transcript
from listenote_win.transcriber import clean_text
from listenote_win.simplify import to_simplified_chinese


class StorageTests(unittest.TestCase):
    def test_markdown_has_time_and_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            path = append_transcript(
                Path(directory),
                datetime(2026, 9, 13, 9, 1, 2),
                datetime(2026, 9, 13, 9, 2, 2),
                "这是一段测试。",
                "large-v3-turbo",
            )
            text = path.read_text(encoding="utf-8")
            self.assertIn("## 09:01:02–09:02:02", text)
            self.assertIn("duration=60.0s", text)
            self.assertIn("这是一段测试。", text)

    def test_known_silence_hallucination_is_removed(self):
        self.assertEqual(clean_text("中文字幕志愿者 杨茜茜"), "")

    def test_normal_text_is_kept(self):
        self.assertEqual(clean_text("  今天讨论安装流程。  \n"), "今天讨论安装流程。")

    @unittest.skipUnless(os.name == "nt", "Windows conversion API")
    def test_windows_simplified_conversion(self):
        self.assertEqual(to_simplified_chinese("繁體中文"), "繁体中文")

    def test_pcm_rms(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sample.wav"
            with wave.open(str(path), "wb") as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(16000)
                wav.writeframes((1000).to_bytes(2, "little", signed=True) * 160)
            self.assertEqual(pcm_rms(path), 1000)


if __name__ == "__main__":
    unittest.main()
