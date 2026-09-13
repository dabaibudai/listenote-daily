from __future__ import annotations

import ctypes
import math
import os
import time
import wave
from array import array
from ctypes import wintypes
from pathlib import Path
from threading import Event


WAVE_FORMAT_PCM = 1
WAVE_MAPPER = 0xFFFFFFFF
CALLBACK_NULL = 0
WHDR_DONE = 0x00000001


class WAVEFORMATEX(ctypes.Structure):
    _fields_ = [
        ("wFormatTag", wintypes.WORD),
        ("nChannels", wintypes.WORD),
        ("nSamplesPerSec", wintypes.DWORD),
        ("nAvgBytesPerSec", wintypes.DWORD),
        ("nBlockAlign", wintypes.WORD),
        ("wBitsPerSample", wintypes.WORD),
        ("cbSize", wintypes.WORD),
    ]


class WAVEHDR(ctypes.Structure):
    _fields_ = [
        ("lpData", ctypes.c_void_p),
        ("dwBufferLength", wintypes.DWORD),
        ("dwBytesRecorded", wintypes.DWORD),
        ("dwUser", ctypes.c_size_t),
        ("dwFlags", wintypes.DWORD),
        ("dwLoops", wintypes.DWORD),
        ("lpNext", ctypes.c_void_p),
        ("reserved", ctypes.c_size_t),
    ]


def pcm_rms(path: Path) -> int:
    with wave.open(str(path), "rb") as wav:
        if wav.getsampwidth() != 2:
            raise ValueError("Only 16-bit PCM is supported")
        samples = array("h")
        samples.frombytes(wav.readframes(wav.getnframes()))
    if not samples:
        return 0
    if os.sys.byteorder != "little":
        samples.byteswap()
    return int(math.sqrt(sum(sample * sample for sample in samples) / len(samples)))


class WaveInRecorder:
    sample_rate = 16000
    channels = 1
    sample_width = 2
    buffer_milliseconds = 200

    def record(self, output: Path, seconds: int, stop_event: Event) -> float:
        if os.name != "nt":
            raise RuntimeError("Microphone recording is available only on Windows")
        output.parent.mkdir(parents=True, exist_ok=True)
        partial = output.with_suffix(output.suffix + ".part")
        winmm = ctypes.WinDLL("winmm")
        winmm.waveInOpen.argtypes = [
            ctypes.POINTER(wintypes.HANDLE), wintypes.UINT, ctypes.POINTER(WAVEFORMATEX),
            ctypes.c_size_t, ctypes.c_size_t, wintypes.DWORD,
        ]
        winmm.waveInOpen.restype = wintypes.UINT
        for name in ("waveInPrepareHeader", "waveInUnprepareHeader", "waveInAddBuffer"):
            function = getattr(winmm, name)
            function.argtypes = [wintypes.HANDLE, ctypes.POINTER(WAVEHDR), wintypes.UINT]
            function.restype = wintypes.UINT
        for name in ("waveInStart", "waveInStop", "waveInReset", "waveInClose"):
            function = getattr(winmm, name)
            function.argtypes = [wintypes.HANDLE]
            function.restype = wintypes.UINT
        handle = wintypes.HANDLE()
        fmt = WAVEFORMATEX(
            WAVE_FORMAT_PCM,
            self.channels,
            self.sample_rate,
            self.sample_rate * self.channels * self.sample_width,
            self.channels * self.sample_width,
            self.sample_width * 8,
            0,
        )
        result = winmm.waveInOpen(
            ctypes.byref(handle), WAVE_MAPPER, ctypes.byref(fmt), 0, 0, CALLBACK_NULL
        )
        if result != 0:
            raise RuntimeError(f"waveInOpen failed with code {result}")

        buffer_size = self.sample_rate * self.sample_width * self.buffer_milliseconds // 1000
        buffers = [ctypes.create_string_buffer(buffer_size) for _ in range(6)]
        headers = [WAVEHDR() for _ in buffers]
        start = time.monotonic()
        try:
            for data, header in zip(buffers, headers):
                header.lpData = ctypes.cast(data, ctypes.c_void_p)
                header.dwBufferLength = buffer_size
                self._check(winmm.waveInPrepareHeader(handle, ctypes.byref(header), ctypes.sizeof(header)), "prepare")
                self._check(winmm.waveInAddBuffer(handle, ctypes.byref(header), ctypes.sizeof(header)), "add")
            self._check(winmm.waveInStart(handle), "start")
            with wave.open(str(partial), "wb") as wav:
                wav.setnchannels(self.channels)
                wav.setsampwidth(self.sample_width)
                wav.setframerate(self.sample_rate)
                while not stop_event.is_set() and time.monotonic() - start < seconds:
                    wrote_data = False
                    for data, header in zip(buffers, headers):
                        if header.dwFlags & WHDR_DONE:
                            if header.dwBytesRecorded:
                                wav.writeframesraw(data.raw[: header.dwBytesRecorded])
                            header.dwBytesRecorded = 0
                            self._check(winmm.waveInAddBuffer(handle, ctypes.byref(header), ctypes.sizeof(header)), "add")
                            wrote_data = True
                    if not wrote_data:
                        time.sleep(0.02)
                winmm.waveInStop(handle)
                winmm.waveInReset(handle)
                for data, header in zip(buffers, headers):
                    if header.dwBytesRecorded:
                        wav.writeframesraw(data.raw[: header.dwBytesRecorded])
        finally:
            winmm.waveInStop(handle)
            winmm.waveInReset(handle)
            for header in headers:
                winmm.waveInUnprepareHeader(handle, ctypes.byref(header), ctypes.sizeof(header))
            winmm.waveInClose(handle)

        elapsed = time.monotonic() - start
        if partial.exists() and partial.stat().st_size > 44:
            partial.replace(output)
        else:
            partial.unlink(missing_ok=True)
            raise RuntimeError("No microphone audio was captured")
        return elapsed

    @staticmethod
    def _check(code: int, operation: str) -> None:
        if code != 0:
            raise RuntimeError(f"waveIn {operation} failed with code {code}")
