import tempfile
import unittest
from datetime import datetime
from pathlib import Path

from listenote_win.config import Settings, TimeWindow, load_settings, parse_windows, should_record


class ConfigTests(unittest.TestCase):
    def test_parse_normal_windows(self):
        self.assertEqual(parse_windows("09:00-12:00,13:30-18:00"), (TimeWindow(540, 720), TimeWindow(810, 1080)))

    def test_cross_midnight_window(self):
        window = parse_windows("22:00-02:00")[0]
        self.assertTrue(window.contains(23 * 60))
        self.assertTrue(window.contains(60))
        self.assertFalse(window.contains(12 * 60))

    def test_zero_length_is_invalid(self):
        with self.assertRaises(ValueError):
            parse_windows("09:00-09:00")

    def test_default_config_is_created(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.ini"
            settings = load_settings(path)
            self.assertTrue(path.exists())
            self.assertEqual(settings.language, "zh")
            self.assertEqual(settings.chunk_seconds, 60)

    def test_schedule_boundaries(self):
        settings = Settings(True, frozenset({1}), (TimeWindow(540, 720),), "zh", 60, 220, Path("model.bin"), "en")
        self.assertTrue(should_record(datetime(2026, 9, 14, 9, 0), settings))
        self.assertFalse(should_record(datetime(2026, 9, 14, 12, 0), settings))
        self.assertFalse(should_record(datetime(2026, 9, 15, 10, 0), settings))

    def test_ui_language_default_is_en(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = load_settings(Path(directory) / "config.ini")
            self.assertEqual(settings.ui_language, "en")

    def test_ui_language_zh(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.ini"
            path.write_text(
                "[schedule]\nenabled = true\ndays = 1\nwindows = 09:00-12:00\n"
                "\n[ui]\nlanguage = zh\n",
                encoding="utf-8",
            )
            self.assertEqual(load_settings(path).ui_language, "zh")

    def test_ui_language_invalid(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.ini"
            path.write_text(
                "[schedule]\nenabled = true\ndays = 1\nwindows = 09:00-12:00\n"
                "\n[ui]\nlanguage = fr\n",
                encoding="utf-8",
            )
            with self.assertRaises(ValueError):
                load_settings(path)


if __name__ == "__main__":
    unittest.main()
