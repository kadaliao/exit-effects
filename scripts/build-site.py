#!/usr/bin/env python3
"""Builds the market: index.json, the effect files, previews and the gallery page, in _site/.

    python3 scripts/build-site.py plan            print the effects whose preview must be rendered
    python3 scripts/build-site.py build [--out _site] [--no-render]

Previews of effects that haven't changed are copied from the live site, so only new and
edited effects are rendered (that needs Exit, ffmpeg, gifski and gifsicle).
"""

import argparse
import datetime
import json
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

import fx

FORMAT = 1


def git(*args) -> str:
    return subprocess.run(["git", *args], cwd=fx.ROOT, capture_output=True, text=True).stdout.strip()


def fetch(url: str, timeout=30):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.read()
    except Exception as e:  # first publish, or the site is down: render everything
        print(f"  (could not fetch {url}: {e})", file=sys.stderr)
        return None


def live_index() -> dict:
    data = fetch(fx.SITE + "index.json")
    try:
        return {e["id"]: e for e in json.loads(data)["effects"]} if data else {}
    except (ValueError, KeyError, TypeError):
        return {}


def entries():
    """Every effect in effects/, with what the index says about it."""
    out = []
    for path in sorted(fx.EFFECTS.glob("*.metal")):
        data = path.read_bytes()
        meta = fx.parse_header(data.decode("utf-8"))
        rel = f"effects/{path.name}"
        sha = fx.sha256(data)
        e = {
            "id": path.stem,
            "name": meta.get("name") or path.stem,
            "name_zh": meta.get("name.zh"),
            "description": meta.get("description"),
            "description_zh": meta.get("description.zh"),
            "author": meta.get("author"),
            "events": fx.events_of(meta),
            "duration": fx.duration_of(meta),
            "requires": meta.get("requires"),
            "file": rel,
            "preview": f"previews/{path.stem}-{sha[:8]}.gif",
            "sha256": sha,
            "size": len(data),
            "added": git("log", "--diff-filter=A", "--format=%cs", "--", rel).split("\n")[-1] or None,
            "updated": git("log", "-1", "--format=%cs", "--", rel) or None,
            "source_url": f"https://github.com/{fx.REPO}/blob/main/{rel}",
        }
        out.append({k: v for k, v in e.items() if v is not None})
    return out


def plan(items, live):
    """Effects with no preview on the live site for their current contents."""
    return [e for e in items if live.get(e["id"], {}).get("preview") != e["preview"]]


def build(out: Path, render: bool):
    items = entries()
    live = live_index()
    todo = {e["id"] for e in plan(items, live)}

    if out.exists():
        shutil.rmtree(out)
    (out / "effects").mkdir(parents=True)
    (out / "previews").mkdir()

    for e in items:
        shutil.copy(fx.ROOT / e["file"], out / e["file"])
        if e["id"] not in todo:
            data = fetch(fx.SITE + e["preview"])
            if data:
                (out / e["preview"]).write_bytes(data)
                print(f"  reuse  {e['preview']}")
            else:
                todo.add(e["id"])

    rendered = 0
    if todo and render:
        with tempfile.TemporaryDirectory() as tmp:
            files = [str(fx.ROOT / f"effects/{i}.metal") for i in sorted(todo)]
            subprocess.run([str(fx.ROOT / "scripts/make-previews.sh"), tmp, *files], check=True)
            for e in items:
                if e["id"] in todo:
                    shutil.move(Path(tmp) / f"{e['id']}.gif", out / e["preview"])
                    rendered += 1
                    print(f"  render {e['preview']}")
    for e in items:
        if not (out / e["preview"]).exists():
            del e["preview"]

    index = {
        "format": FORMAT,
        "name": "Exit Effects",
        "name_zh": "Exit 特效市场",
        "homepage": fx.SITE,
        "repo": f"https://github.com/{fx.REPO}",
        "submit": f"https://github.com/{fx.REPO}/issues/new?template=submit-effect.yml",
        "mirrors": fx.MIRRORS,
        "updated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "effects": items,
    }
    (out / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n")
    for f in (fx.ROOT / "site").iterdir():
        if f.is_file():
            shutil.copy(f, out / f.name)
    (out / ".nojekyll").write_text("")
    missing = sum(1 for e in items if "preview" not in e)
    print(f"▸ {len(items)} effects, {rendered} previews rendered" + (f", {missing} without a preview" if missing else "") + f" → {out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["plan", "build"])
    ap.add_argument("--out", type=Path, default=fx.ROOT / "_site")
    ap.add_argument("--no-render", action="store_true", help="leave out previews that would need rendering")
    a = ap.parse_args()
    if a.mode == "plan":
        for e in plan(entries(), live_index()):
            print(e["id"])
    else:
        build(a.out, render=not a.no_render)


if __name__ == "__main__":
    main()
