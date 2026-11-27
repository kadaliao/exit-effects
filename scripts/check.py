#!/usr/bin/env python3
"""Checks effect files the way the market's CI does.

    python3 scripts/check.py effects/aurora.metal ...    these files
    python3 scripts/check.py --changed origin/main       effects added or changed since that ref
    python3 scripts/check.py --all                       every effect in effects/
      [--report report.md]   also write a Markdown report
      [--sheet frames.png]   also render a strip of frames for each effect that compiles

Needs Exit (EXIT_BIN, or build/Exit.app from scripts/get-exit.sh).
Exit status 1 when any effect fails.
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import fx

PASS, FAIL, NOTE = "✅", "❌", "ℹ️"


class Result:
    def __init__(self, path: Path):
        self.path = path
        self.id = path.stem
        self.rows = []        # (mark, label, detail)
        self.details = []     # (title, text) shown in code blocks under the table
        self.meta = {}
        self.compiled = False
        self.ms = None

    @property
    def ok(self) -> bool:
        return all(mark != FAIL for mark, _, _ in self.rows)

    def add(self, ok, label, detail=""):
        mark = NOTE if ok is None else (PASS if ok else FAIL)
        self.rows.append((mark, label, detail))
        return ok


def check(path: Path, builtins: set, version: str) -> Result:
    r = Result(path)
    data = path.read_bytes()

    # The file itself
    rel = path.resolve().relative_to(fx.ROOT) if path.resolve().is_relative_to(fx.ROOT) else path
    in_place = path.resolve().parent == fx.EFFECTS.resolve()
    good_id = bool(fx.ID_RE.match(r.id)) and r.id != "prelude"
    if not good_id:
        r.add(False, "File name · 文件名",
              f"`{rel}`: use 2–40 lowercase letters, digits and dashes, like `paper-plane.metal`")
    elif r.id in builtins:
        r.add(False, "File name · 文件名", f"`{r.id}` is a built-in effect in Exit; pick another name")
    elif not in_place:
        r.add(False, "File name · 文件名", f"`{rel}` should be in `effects/`")
    else:
        r.add(True, "File name · 文件名", f"`effects/{r.id}.metal`")
    if len(data) > fx.MAX_BYTES:
        r.add(False, "Size · 大小", f"{len(data) // 1024} KB; the limit is {fx.MAX_BYTES // 1024} KB")
    try:
        source = data.decode("utf-8")
    except UnicodeDecodeError:
        r.add(False, "Text · 文本", "not UTF-8 text")
        return r

    # Header
    meta = r.meta = fx.parse_header(source)
    missing = [k for k in ("name", "author", "description") if not meta.get(k)]
    if missing:
        r.add(False, "Header · 头部", "add " + ", ".join(f"`// @{k} …`" for k in missing) + " at the top")
    else:
        extras = [k for k in ("name.zh", "description.zh") if meta.get(k)]
        r.add(True, "Header · 头部", f"**{meta['name']}** by {meta['author']}"
              + ("" if extras else " (tip: add `@name.zh` and `@description.zh` for Chinese users)"))
    raw_events = [e for e in re.split(r"[,\s]+", meta.get("events", "")) if e]
    unknown = [e for e in raw_events if e.lower() not in fx.EVENTS]
    if unknown:
        r.add(False, "Events · 事件", "unknown: " + ", ".join(f"`{e}`" for e in unknown)
              + "; use `close`, `quit`, `minimize`, `open`")
    else:
        r.add(True, "Events · 事件", ", ".join(fx.events_of(meta)) + f" · {fx.duration_of(meta):g}s")
    if meta.get("requires"):
        need = meta["requires"]
        if not re.match(r"^\d+(\.\d+){0,2}$", need):
            r.add(False, "Requires · 版本", f"`@requires {need}` should look like `0.3` or `0.3.1`")
        elif version != "dev" and fx.version_tuple(need) > fx.version_tuple(version):
            r.add(False, "Requires · 版本", f"needs Exit {need}, but the newest release here is {version}")
        else:
            r.add(True, "Requires · 版本", f"Exit {need} or later")
    if re.search(r"^\s*#\s*(include|import)\b", source, re.M):
        r.add(False, "Includes · 引用", "remove `#include` / `#import`: the prelude already has everything")

    # Compile, behave, and stay fast, in a folder that holds only this effect.
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copy(path, Path(tmp) / f"{r.id}.metal")
        base = [fx.exit_bin(), "--effects-dir", tmp, "--only", r.id]
        out = fx.run(base + ["--check"])
        r.compiled = out.returncode == 0 and f"✓ {r.id}" in out.stdout
        if not r.add(r.compiled, "Compiles · 编译"):
            r.details.append(("Compiler · 编译器", "\n".join(out.stdout.splitlines()[1:40]) or out.stderr[-3000:]))
            return r

        out = fx.run(base + ["--validate", "--budget", str(fx.BUDGET_MS)])
        problems = [l.strip()[2:] for l in out.stdout.splitlines() if l.strip().startswith("- ")]
        if out.returncode == 0 and not problems:
            r.add(True, "Start and finish · 起止", "starts as the untouched window, ends fully transparent")
        else:
            r.add(False, "Start and finish · 起止", "see below")
            r.details.append(("Problems · 问题", "\n".join(f"- {p}" for p in problems) or out.stdout[-3000:]))

        out = fx.run(base + ["--bench", "--max-ms", str(fx.BUDGET_MS)])
        m = re.search(r"([\d.]+) ms/frame", out.stdout)
        r.ms = float(m.group(1)) if m else None
        speed = f"{r.ms:.1f} ms per Retina frame on the CI Mac (limit {fx.BUDGET_MS} ms)" if m else out.stdout[-500:]
        r.add(out.returncode == 0 and m is not None, "Speed · 性能", speed)
    return r


def markdown(results, version) -> str:
    lines = []
    for r in results:
        name = r.meta.get("name") or r.id
        zh = r.meta.get("name.zh")
        title = f"{name} · {zh}" if zh and zh != name else name
        lines += [f"#### {PASS if r.ok else FAIL} {title} (`{r.id}`)", "",
                  "| | Check · 检查 | Result · 结果 |", "|---|---|---|"]
        lines += [f"| {mark} | {label} | {detail} |" for mark, label, detail in r.rows]
        for head, text in r.details:
            lines += ["", f"**{head}**", "", "```", text.strip()[:6000], "```"]
        lines.append("")
    lines.append(f"<sub>Checked with Exit {version}.</sub>")
    return "\n".join(lines) + "\n"


def changed_files(ref: str):
    out = subprocess.run(["git", "diff", "--name-only", "--diff-filter=AMR", f"{ref}...HEAD", "--", "effects/"],
                         cwd=fx.ROOT, capture_output=True, text=True, check=True).stdout
    return [fx.ROOT / l for l in out.split() if l.endswith(".metal")]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--changed", metavar="REF")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--report", type=Path)
    ap.add_argument("--sheet", type=Path)
    a = ap.parse_args()

    files = list(a.files)
    if a.changed:
        files += changed_files(a.changed)
    if a.all:
        files += sorted(fx.EFFECTS.glob("*.metal"))
    if not files:
        print("No effects to check.")
        if a.report:
            a.report.write_text("No effect files changed.\n")
        return 0

    version = fx.exit_version()
    builtins = fx.builtin_ids()
    results = [check(Path(f), builtins, version) for f in files]
    report = markdown(results, version)
    print(report)
    if a.report:
        a.report.write_text(report)

    if a.sheet:
        good = [r for r in results if r.compiled]
        if good:
            with tempfile.TemporaryDirectory() as tmp:
                for r in good:
                    shutil.copy(r.path, Path(tmp) / f"{r.id}.metal")
                fx.run([fx.exit_bin(), "--effects-dir", tmp, "--only", ",".join(r.id for r in good),
                        "--render-sheet", str(a.sheet), "--frames", "6"])
    return 0 if all(r.ok for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
