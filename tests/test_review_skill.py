"""Portable discovery and non-destructive standalone installation tests."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from datetime import date, timedelta
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "finder", REPO / "skills/listenote-daily-review/scripts/find_transcript.py")
finder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(finder)


class ReviewSkillTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="listenote-review-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.day = date(2026, 8, 20)
        self.dirs = finder.transcript_dirs(home=self.root, environ={})

    def transcript(self, directory, text="## 09:00:00–09:00:30\n测试记录\n"):
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / f"{self.day}.md"
        path.write_text(text, encoding="utf-8")
        return path

    def test_current_user_discovery(self):
        with patch.object(Path, "home", return_value=self.root):
            self.assertEqual(finder.transcript_dirs(environ={}), self.dirs)
        path = self.transcript(self.dirs[0])
        payload, code = finder.inspect(self.dirs, self.day)
        self.assertEqual(code, 0)
        self.assertEqual(payload["path"], str(path))
        self.assertEqual(payload["segments"], 1)

    def test_legacy_and_precedence(self):
        old = self.transcript(self.dirs[1])
        self.assertEqual(finder.inspect(self.dirs, self.day)[0]["path"], str(old))
        new = self.transcript(self.dirs[0])
        self.assertEqual(finder.inspect(self.dirs, self.day)[0]["path"], str(new))

    def test_explicit_and_environment_precedence(self):
        env = {"LISTENOTE_TRANSCRIPTS_DIR": str(self.root / "custom notes"),
               "LISTENOTE_DAILY_ROOT": str(self.root / "runtime")}
        self.assertEqual(finder.transcript_dirs(environ=env), [self.root / "custom notes"])
        self.assertEqual(finder.transcript_dirs(str(self.root / "override"), environ=env),
                         [self.root / "override"])
        del env["LISTENOTE_TRANSCRIPTS_DIR"]
        self.assertEqual(finder.transcript_dirs(environ=env), [self.root / "runtime/records/transcripts"])

    def test_missing_date_never_substitutes(self):
        self.transcript(self.dirs[0])
        payload, code = finder.inspect(self.dirs, self.day + timedelta(days=1))
        self.assertEqual(code, 1)
        self.assertFalse(payload["exists"])
        self.assertEqual(len(payload["nearby"]), 1)
        self.assertTrue(payload["path"].endswith("2026-08-21.md"))

    def test_empty_directory_and_explicit_no_fallback(self):
        self.dirs[0].mkdir(parents=True)
        payload, code = finder.inspect(self.dirs)
        self.assertEqual(code, 0)
        self.assertEqual(payload["nearby"], [])
        self.transcript(self.dirs[0])
        self.assertEqual(finder.inspect([self.root / "wrong"], self.day)[1], 1)

    def test_read_error_has_path_and_reason(self):
        target = self.transcript(self.dirs[0])
        target.write_bytes(b"\xff")
        payload, code = finder.inspect(self.dirs, self.day)
        self.assertEqual(code, 2)
        self.assertEqual(payload["path"], str(target))
        self.assertIn("UnicodeDecodeError", payload["error"])

    def test_standalone_install_preserves_edits(self):
        target = self.root / "agent skills/listenote-daily-review"
        command = ["/bin/zsh", str(REPO / "scripts/install-review-skill.sh"), "--target", str(target)]
        subprocess.run(command, check=True)
        self.assertTrue((target / "scripts/find_transcript.py").is_file())
        skill = target / "SKILL.md"
        skill.write_text("user edits\n")
        subprocess.run(command, check=True)
        self.assertEqual(skill.read_text(), "user edits\n")


if __name__ == "__main__":
    unittest.main()
