from __future__ import annotations

import ctypes
import os
from ctypes import wintypes


LCMAP_SIMPLIFIED_CHINESE = 0x02000000


def to_simplified_chinese(text: str) -> str:
    if not text or os.name != "nt":
        return text
    function = ctypes.windll.kernel32.LCMapStringEx
    function.argtypes = [
        wintypes.LPCWSTR,
        wintypes.DWORD,
        wintypes.LPCWSTR,
        ctypes.c_int,
        wintypes.LPWSTR,
        ctypes.c_int,
        ctypes.c_void_p,
        ctypes.c_void_p,
        wintypes.LPARAM,
    ]
    function.restype = ctypes.c_int
    required = function("zh-CN", LCMAP_SIMPLIFIED_CHINESE, text, len(text), None, 0, None, None, 0)
    if required <= 0:
        return text
    buffer = ctypes.create_unicode_buffer(required)
    written = function(
        "zh-CN", LCMAP_SIMPLIFIED_CHINESE, text, len(text), buffer, required, None, None, 0
    )
    return buffer.value if written > 0 else text
