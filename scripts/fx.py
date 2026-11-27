"""Shared helpers for the market scripts: effect headers, the rules, and running Exit."""

import hashlib
import os
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EFFECTS = ROOT / "effects"
# A fork publishes its own market: everything follows the repository it runs in.
REPO = os.environ.get("GITHUB_REPOSITORY") or "kadaliao/exit-effects"
SITE = os.environ.get("MARKET_SITE") or "https://{}.github.io/{}/".format(*REPO.lower().split("/"))
MIRRORS = [f"https://cdn.jsdelivr.net/gh/{REPO}@gh-pages/"]

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,39}$")
EVENTS = ("close", "quit", "minimize", "open")
MAX_BYTES = 32 * 1024
# GPU time per Retina frame on a GitHub macOS runner, which is about 4x slower than an
# Apple-silicon Mac. The slowest built-in effect takes about 16 ms there.
BUDGET_MS = 20


def exit_bin() -> str:
    return os.environ.get("EXIT_BIN") or str(ROOT / "build/Exit.app/Contents/MacOS/Exit")


def parse_header(source: str) -> dict:
    """The `// @key value` lines at the top, read the same way Exit reads them."""
    meta = {}
    for raw in source.split("\n")[:60]:
        line = raw.strip()
        if not line.startswith("//"):
            if line == "":
                continue
            break
        body = line[2:].strip()
        if not body.startswith("@"):
            continue
        key, _, value = body[1:].partition(" ")
        meta[key.lower()] = value.strip()   # a repeated key: the last one wins, as in Exit
    return meta


def events_of(meta: dict) -> list:
    raw = re.split(r"[,\s]+", meta.get("events", ""))
    found = [e for e in EVENTS if e in {r.lower() for r in raw}]
    return found or ["close", "quit", "minimize"]


def duration_of(meta: dict) -> float:
    try:
        return min(max(float(meta.get("duration", "0.7")), 0.15), 6.0)
    except ValueError:
        return 0.7


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def version_tuple(v: str) -> tuple:
    return tuple(int(re.match(r"\d*", p).group() or 0) for p in v.split("."))


def run(args, timeout=180) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout)


def exit_version() -> str:
    return run([exit_bin(), "--version"]).stdout.strip()


def builtin_ids() -> set:
    """Effects that ship inside Exit: market effects may not reuse their names."""
    with tempfile.TemporaryDirectory() as empty:
        out = run([exit_bin(), "--effects-dir", empty, "--check"]).stdout
    return {m.group(1) for m in re.finditer(r"^[✓✗] (\S+)", out, re.M)}


def slug(text: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:40].strip("-")
