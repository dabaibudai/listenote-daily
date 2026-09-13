from __future__ import annotations

import ctypes
import logging
import os
import sys
from logging.handlers import RotatingFileHandler

from .paths import AppPaths
from .tray import TrayApp


def _single_instance() -> object:
    mutex = ctypes.windll.kernel32.CreateMutexW(None, False, "Local\\ListenoteDaily.SingleInstance")
    if not mutex or ctypes.windll.kernel32.GetLastError() == 183:
        raise RuntimeError("Listenote Daily is already running")
    return mutex


def _configure_logging(paths: AppPaths) -> None:
    paths.logs.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(
        paths.logs / "listenote.log", maxBytes=2_000_000, backupCount=3, encoding="utf-8"
    )
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(threadName)s %(message)s"))
    logging.basicConfig(level=logging.INFO, handlers=[handler])


def main() -> None:
    if os.name != "nt":
        print("Listenote Daily for Windows can only run on Windows.", file=sys.stderr)
        raise SystemExit(2)
    mutex = _single_instance()
    paths = AppPaths.discover()
    paths.ensure_directories()
    _configure_logging(paths)
    try:
        TrayApp(paths).run()
    except Exception:
        logging.exception("Fatal application error")
        ctypes.windll.user32.MessageBoxW(None, "Listenote Daily could not start. Check logs.", "Listenote Daily", 0x10)
        raise
    finally:
        ctypes.windll.kernel32.CloseHandle(mutex)
