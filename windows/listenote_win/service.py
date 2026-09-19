from __future__ import annotations

import logging
import queue
import threading
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable

from .audio import WaveInRecorder, pcm_rms
from .config import Settings, load_settings, should_record
from .paths import AppPaths
from .storage import append_transcript
from .transcriber import WhisperTranscriber


@dataclass(frozen=True)
class PendingChunk:
    path: Path
    started: datetime
    ended: datetime
    settings: Settings


class ListenoteService:
    def __init__(self, paths: AppPaths, state_callback: Callable[[str], None] | None = None) -> None:
        self.paths = paths
        self.state_callback = state_callback or (lambda _state: None)
        self.log = logging.getLogger("listenote")
        self._shutdown = threading.Event()
        self._chunk_stop = threading.Event()
        self._manual_override: bool | None = None
        self._queue: queue.Queue[PendingChunk | None] = queue.Queue(maxsize=4)
        self._capture_thread = threading.Thread(target=self._capture_loop, name="capture", daemon=True)
        self._worker_thread = threading.Thread(target=self._transcription_loop, name="transcribe", daemon=True)
        self._lock = threading.Lock()
        self._capturing = False
        self._transcribing = False
        self._capture_started: datetime | None = None
        self._last_error = ""

    def start(self) -> None:
        self.paths.ensure_directories()
        self._cleanup_stale_temp()
        self._capture_thread.start()
        self._worker_thread.start()
        self._notify()

    def start_manual(self) -> None:
        self._manual_override = True
        self._chunk_stop.clear()
        self.log.info("Manual start")
        self._notify()

    def stop_manual(self) -> None:
        self._manual_override = False
        self._chunk_stop.set()
        self.log.info("Manual stop")
        self._notify()

    def use_schedule(self) -> None:
        self._manual_override = None
        try:
            scheduled_now = should_record(datetime.now(), load_settings(self.paths.config))
        except Exception:
            scheduled_now = False
        if scheduled_now:
            self._chunk_stop.clear()
        else:
            self._chunk_stop.set()
        self.log.info("Schedule mode restored")
        self._notify()

    def shutdown(self) -> None:
        self._shutdown.set()
        self._chunk_stop.set()
        self._capture_thread.join(timeout=5)
        try:
            self._queue.put_nowait(None)
        except queue.Full:
            self._discard_oldest()
            self._queue.put_nowait(None)
        self._worker_thread.join(timeout=20)

    @property
    def status(self) -> str:
        with self._lock:
            if self._last_error:
                return "Error"
            if self._capturing:
                return "Active"
            if self._transcribing or not self._queue.empty():
                return "Processing"
            return "Idle"

    @property
    def active_seconds(self) -> float | None:
        with self._lock:
            if self._capturing and self._capture_started is not None:
                return (datetime.now() - self._capture_started).total_seconds()
        return None

    @property
    def pending_count(self) -> int:
        return self._queue.qsize()

    def _wanted(self, settings: Settings) -> bool:
        if self._manual_override is not None:
            return self._manual_override
        return should_record(datetime.now(), settings)

    def _capture_loop(self) -> None:
        recorder = WaveInRecorder()
        while not self._shutdown.is_set():
            try:
                settings = load_settings(self.paths.config)
                if not self._wanted(settings):
                    self._set_activity(capturing=False)
                    self._chunk_stop.clear()
                    self._shutdown.wait(2)
                    continue
                self._chunk_stop.clear()
                started = datetime.now()
                self._capture_started = started
                wav_path = self.paths.temp / f"chunk-{started:%Y%m%d-%H%M%S-%f}.wav"
                self._set_activity(capturing=True, error="")
                recorder.record(wav_path, settings.chunk_seconds, self._combined_stop())
                ended = datetime.now()
                self._capture_started = None
                self._set_activity(capturing=False)
                if wav_path.exists() and pcm_rms(wav_path) >= settings.minimum_rms:
                    self._enqueue(PendingChunk(wav_path, started, ended, settings))
                else:
                    wav_path.unlink(missing_ok=True)
            except Exception as exc:
                self._capture_started = None
                self._set_activity(capturing=False, error=str(exc))
                self.log.exception("Audio capture failed")
                self._shutdown.wait(5)

    def _combined_stop(self) -> "_StopProxy":
        return _StopProxy(self._shutdown, self._chunk_stop)

    def _enqueue(self, item: PendingChunk) -> None:
        if self._queue.full():
            self.log.warning("Transcription queue full; discarding oldest pending chunk")
            self._discard_oldest()
        self._queue.put_nowait(item)
        self._notify()

    def _discard_oldest(self) -> None:
        try:
            old = self._queue.get_nowait()
        except queue.Empty:
            return
        if old is not None:
            old.path.unlink(missing_ok=True)
            old.path.with_suffix(".txt").unlink(missing_ok=True)
        self._queue.task_done()

    def _transcription_loop(self) -> None:
        while True:
            item = self._queue.get()
            if item is None:
                self._queue.task_done()
                return
            txt_path = item.path.with_suffix(".txt")
            try:
                self._set_activity(transcribing=True, error="")
                model = self.paths.root / item.settings.model_relative
                transcriber = WhisperTranscriber(self.paths.whisper_exe, model, item.settings.language)
                text = transcriber.transcribe(item.path)
                if text:
                    append_transcript(
                        self.paths.notes, item.started, item.ended, text, model.name.removeprefix("ggml-").removesuffix(".bin")
                    )
            except Exception as exc:
                self._set_activity(error=str(exc))
                self.log.exception("Transcription failed")
            finally:
                item.path.unlink(missing_ok=True)
                txt_path.unlink(missing_ok=True)
                self._queue.task_done()
                self._set_activity(transcribing=False)

    def _set_activity(
        self,
        *,
        capturing: bool | None = None,
        transcribing: bool | None = None,
        error: str | None = None,
    ) -> None:
        with self._lock:
            if capturing is not None:
                self._capturing = capturing
            if transcribing is not None:
                self._transcribing = transcribing
            if error is not None:
                self._last_error = error
        self._notify()

    def _notify(self) -> None:
        try:
            self.state_callback(self.status)
        except Exception:
            self.log.debug("State callback failed", exc_info=True)

    def _cleanup_stale_temp(self) -> None:
        for path in self.paths.temp.glob("chunk-*"):
            try:
                path.unlink()
            except OSError:
                self.log.warning("Could not remove stale temporary file: %s", path)


class _StopProxy:
    def __init__(self, *events: threading.Event) -> None:
        self.events = events

    def is_set(self) -> bool:
        return any(event.is_set() for event in self.events)
