#!/usr/bin/env python3
"""Read-only transcript discovery; Python standard library only."""

from __future__ import annotations

import argparse
import json
import os
from datetime import date, timedelta
from pathlib import Path


def transcript_dirs(explicit=None, *, home=None, environ=None):
    env = os.environ if environ is None else environ
    base = Path.home() if home is None else Path(home)
    chosen = explicit or env.get("LISTENOTE_TRANSCRIPTS_DIR")
    if chosen:
        return [Path(chosen).expanduser().resolve()]
    if env.get("LISTENOTE_DAILY_ROOT"):
        return [Path(env["LISTENOTE_DAILY_ROOT"]).expanduser().resolve() / "records/transcripts"]
    support = base / "Library/Application Support"
    return [support / app / "records/transcripts" for app in ("Listenote Daily", "WhisperDaily")]


def resolve_date(value):
    if value == "today":
        return date.today()
    if value == "yesterday":
        return date.today() - timedelta(days=1)
    return date.fromisoformat(value)


def inspect(dirs, target=None):
    payload = {"checked_dirs": [str(p) for p in dirs]}
    if target is not None:
        payload["date"] = target.isoformat()
    try:
        if target is None:
            selected = next((p for p in dirs if p.is_dir()), None)
            payload.update(exists=selected is not None, path=str(selected or dirs[0]))
            payload["nearby"] = [str(p) for d in dirs if d.is_dir() for p in sorted(d.glob("*.md"))[-7:]]
        else:
            candidates = [p / f"{target.isoformat()}.md" for p in dirs]
            selected = next((p for p in candidates if p.is_file()), None)
            payload.update(exists=selected is not None, path=str(selected or candidates[0]))
            if selected is not None:
                content = selected.read_text(encoding="utf-8")
                payload.update(bytes=selected.stat().st_size,
                               segments=sum(line.startswith("## ") for line in content.splitlines()))
            else:
                payload["nearby"] = [str(p) for d in dirs if d.is_dir() for p in sorted(d.glob("*.md"))[-7:]]
        if selected is None:
            payload["error"] = "Transcript file not found" if target else "Transcript directory not found"
            return payload, 1
        return payload, 0
    except (OSError, UnicodeError) as exc:
        payload["error"] = f"{type(exc).__name__}: {exc}"
        return payload, 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", default="yesterday", help="YYYY-MM-DD, today, yesterday")
    parser.add_argument("--transcripts-dir", help="Explicit Markdown directory; disables fallback")
    parser.add_argument("--check", action="store_true", help="Check directories without requiring a date file")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        target = None if args.check else resolve_date(args.date)
    except ValueError:
        parser.error("--date must be YYYY-MM-DD, today, or yesterday")
    payload, code = inspect(transcript_dirs(args.transcripts_dir), target)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(payload.get("path", ""))
        if payload.get("error"):
            print(payload["error"])
    return code


if __name__ == "__main__":
    raise SystemExit(main())
