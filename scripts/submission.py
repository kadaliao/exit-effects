#!/usr/bin/env python3
"""Turns a submission issue (sent by `Exit --market submit`) into a pull request. Run by
.github/workflows/submission.yml.

    python3 scripts/submission.py read [event.json]
        Reads the issue (default: $GITHUB_EVENT_PATH), writes effects/<id>.metal and checks it.
        An effect's name belongs to the GitHub account that first submitted it: the same name
        from that account is an update, from anyone else it fails the checks.
        Saves its findings to build/submission.json and prints outputs for the workflow:
        id, compiled (true/false), ok (true/false).
    python3 scripts/submission.py publish [preview.gif]
        Uploads the preview, opens or updates the pull request when the checks pass (closes
        it when they don't) and merges it right away, labels the issue and posts the report
        as a comment.

The issue body is untrusted text: it is only ever passed as data, never to a shell.
"""

import base64
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

import check
import fx

STATE = fx.ROOT / "build/submission.json"
ASSETS = "review-assets"
BOT = ("github-actions[bot]", "41898282+github-actions[bot]@users.noreply.github.com")
LABEL_SUBMISSION, LABEL_OK, LABEL_FIX = "submission", "checks passed", "needs changes"


def sections(body: str) -> dict:
    """Issue-form answers by heading, lowercased: {'effect id · 特效 id': '...'}."""
    out, cur = {}, None
    for line in body.replace("\r\n", "\n").split("\n"):
        m = re.match(r"^###\s+(.+?)\s*$", line)
        if m:
            cur = m.group(1).lower()
            out[cur] = []
        elif cur is not None:
            out[cur].append(line)
    return {k: "\n".join(v).strip() for k, v in out.items()}


def field(sec: dict, prefix: str) -> str:
    for k, v in sec.items():
        if k.startswith(prefix):
            return "" if v == "_No response_" else v
    return ""


def code_of(text: str) -> str:
    lines = text.split("\n")
    fences = [i for i, l in enumerate(lines) if l.strip().startswith("```")]
    if len(fences) >= 2:
        lines = lines[fences[0] + 1:fences[-1]]
    return "\n".join(lines).strip("\n") + "\n"


def with_author(source: str, login: str) -> str:
    """Adds `// @author <login>` after the name lines when the header has no author."""
    if fx.parse_header(source).get("author"):
        return source
    lines = source.split("\n")
    at = 0
    for i, l in enumerate(lines[:60]):
        if re.match(r"^\s*//\s*@name(\.zh)?\b", l):
            at = i + 1
    lines.insert(at, f"// @author {login}")
    return "\n".join(lines)


def output(**kv):
    path = os.environ.get("GITHUB_OUTPUT")
    text = "".join(f"{k}={v}\n" for k, v in kv.items())
    if path:
        with open(path, "a") as f:
            f.write(text)
    print(text, end="")


def read(event_path: str):
    event = json.loads(Path(event_path).read_text())
    issue = event["issue"]
    login = issue["user"]["login"]
    sec = sections(issue.get("body") or "")
    source = code_of(field(sec, "shader source"))
    # "Paper Plane" or "paper_plane.metal" becomes paper-plane; an empty or all-Chinese ID falls back to @name.
    raw_id = field(sec, "effect id").strip().lower().removesuffix(".metal")
    eid = fx.slug(raw_id) or fx.slug(fx.parse_header(source).get("name", ""))

    state = {"issue": issue["number"], "login": login, "user_id": issue["user"]["id"], "id": eid,
             "ok": False, "compiled": False, "report": "", "replaces": None}
    fx.ROOT.joinpath("build").mkdir(exist_ok=True)

    if not re.search(r"\beffect\s*\(", source):
        state["report"] = ("❌ I couldn't find the shader in this issue. Send the effect with "
                           "`Exit --market submit <file>`. · 没有找到着色器代码，请用 `Exit --market submit <文件>` 投稿。\n")
    elif not fx.ID_RE.match(eid) or eid == "prelude":
        state["report"] = (f"❌ `{eid or '(empty)'}` can't be a file name. Rename the file to 2–40 lowercase letters, "
                           "digits and dashes, like `paper-plane.metal`. · 文件名只能用小写字母、数字和短横线，例如 `paper-plane.metal`。\n")
    else:
        path = fx.EFFECTS / f"{eid}.metal"
        taken = None   # the name is someone else's effect: (its author, whether this is the same code)
        if path.exists():
            old = path.read_text()
            by = fx.parse_header(old).get("author") or "?"
            if fx.owner_id(eid) == issue["user"]["id"]:
                state["replaces"] = by
            else:
                taken = (by, fx.shape(old) == fx.shape(source))
        fx.EFFECTS.mkdir(exist_ok=True)
        path.write_text(with_author(source, login))
        result = check.check(path, fx.builtin_ids(), fx.exit_version())
        if taken:
            result.add(False, "Name · 名称", f"`{eid}` is already an effect by {taken[0]} in the market"
                       + (", and this is the same code: the market keeps one copy of each effect" if taken[1] else
                          ". To submit yours as a new effect, give the file another name (and its `@name` too)")
                       + f" · `{eid}` 已经是 {taken[0]} 的特效" + ("，而且代码相同" if taken[1] else "，要作为新特效投稿请给文件换个名字"))
        elif state["replaces"] is not None:
            result.add(None, "Update · 更新", f"a new version of your `{eid}`")
        state.update(ok=result.ok, compiled=result.compiled, name=result.meta.get("name") or eid,
                     report=check.markdown([result], fx.exit_version()))
    STATE.write_text(json.dumps(state))
    output(id=state["id"] if fx.ID_RE.match(state["id"] or "") else "",
           compiled=str(state["compiled"]).lower(), ok=str(state["ok"]).lower())


def gh(*args, check_=True, input_=None) -> str:
    r = subprocess.run(["gh", *args], capture_output=True, text=True, input=input_)
    if check_ and r.returncode != 0:
        raise SystemExit(f"gh {' '.join(args[:3])} failed: {r.stderr}")
    return r.stdout.strip()


def git(*args):
    subprocess.run(["git", *args], cwd=fx.ROOT, check=True)


def upload_preview(gif: Path, state: dict):
    """Puts the preview on the review-assets branch so the comment can show it. Returns its URL."""
    repo = os.environ["GITHUB_REPOSITORY"]
    if subprocess.run(["gh", "api", f"repos/{repo}/branches/{ASSETS}", "--silent"], capture_output=True).returncode != 0:
        main_sha = gh("api", f"repos/{repo}/git/ref/heads/main", "--jq", ".object.sha")
        gh("api", "-X", "POST", f"repos/{repo}/git/refs", "-f", f"ref=refs/heads/{ASSETS}", "-f", f"sha={main_sha}")
    sha = fx.sha256((fx.EFFECTS / f"{state['id']}.metal").read_bytes())[:8]
    path = f"review/{state['issue']}/{state['id']}-{sha}.gif"
    existing = gh("api", f"repos/{repo}/contents/{path}?ref={ASSETS}", "--jq", ".sha", check_=False)
    body = {"message": f"Preview for #{state['issue']}", "branch": ASSETS,
            "content": base64.b64encode(gif.read_bytes()).decode()}
    if re.fullmatch(r"[0-9a-f]{40}", existing or ""):
        body["sha"] = existing
    gh("api", "-X", "PUT", f"repos/{repo}/contents/{path}", "--input", "-", input_=json.dumps(body))
    return f"https://raw.githubusercontent.com/{repo}/{ASSETS}/{path}"


def merge(repo: str, pr: int) -> bool:
    """Rebase-merges the pull request (keeping the submitter as commit author). GitHub needs a
    moment to work out whether a new pull request can be merged, so this tries a few times."""
    for attempt in range(6):
        r = subprocess.run(["gh", "api", "-X", "PUT", f"repos/{repo}/pulls/{pr}/merge", "-f", "merge_method=rebase"],
                           capture_output=True, text=True)
        if r.returncode == 0:
            return True
        print(f"merge #{pr}, try {attempt + 1}: {r.stderr.strip() or r.stdout.strip()}")
        time.sleep(10)
    return False


def publish(gif: str | None):
    state = json.loads(STATE.read_text())
    repo = os.environ["GITHUB_REPOSITORY"]
    n = state["issue"]
    branch = f"submission/{n}"
    preview = upload_preview(Path(gif), state) if gif and Path(gif).exists() else None

    open_prs = json.loads(gh("pr", "list", "--head", branch, "--state", "open", "--json", "number") or "[]")
    pr = open_prs[0]["number"] if open_prs else None
    if state["ok"]:
        login, uid = state["login"], state["user_id"]
        git("checkout", "-B", branch, "origin/main")
        git("add", f"effects/{state['id']}.metal")
        git("-c", f"user.name={BOT[0]}", "-c", f"user.email={BOT[1]}", "commit", "--allow-empty",
            "--author", f"{login} <{uid}+{login}@users.noreply.github.com>",
            "-m", f"{'Update' if state['replaces'] is not None else 'Add'} {state['name']}", "-m", f"Submitted in #{n}.")
        git("push", "-f", "origin", f"{branch}:{branch}")
        body = (f"Submitted by @{login} in #{n}.\n\nCloses #{n}\n\n"
                + (f"![preview]({preview})\n\n" if preview else "") + state["report"])
        if pr:
            gh("pr", "edit", str(pr), "--body", body)
        else:
            verb = "Update" if state["replaces"] is not None else "Add"
            url = gh("pr", "create", "--base", "main", "--head", branch,
                     "--title", f"{verb} effect: {state['name']}", "--body", body)
            pr = int(url.rstrip("/").split("/")[-1])
    elif pr:
        gh("pr", "close", str(pr), "--comment", f"The checks in #{n} fail now; closing until they pass again.")
        pr = None

    merged = state["ok"] and merge(repo, pr)
    if merged:
        gh("api", "-X", "DELETE", f"repos/{repo}/git/refs/heads/{branch}", check_=False)
        # Merging with the workflow's token doesn't start publish.yml by itself; a dispatch does.
        gh("workflow", "run", "publish.yml", "--ref", "main", check_=False)
        # "Closes #n" normally did this already. Closed before the reply, so Exit sees "In the market" right away.
        gh("issue", "close", str(n), "--reason", "completed", check_=False)

    if merged:
        status = (f"✅ All checks passed. Merged in #{pr}: the effect reaches everyone's Market within a few "
                  "minutes. To change it later, press Submit in Exit again (or run `Exit --market submit`). · "
                  f"检查全部通过，已通过 #{pr} 合并，几分钟后就会出现在所有人的特效市场里。以后要修改，在 Exit "
                  "里再点一次投稿（或再运行一次 `Exit --market submit`）即可。")
    elif state["ok"]:
        status = (f"✅ All checks passed. Pull request: #{pr}. It couldn't be merged automatically, so the "
                  "maintainer takes a look. To change the effect, press Submit in Exit again (or run "
                  "`Exit --market submit`): it updates this issue. · "
                  "检查全部通过，已提交 PR，但没能自动合并，维护者会来处理。要修改的话在 Exit 里再点一次投稿"
                  "（或再运行一次 `Exit --market submit`），会更新这个 issue。")
    else:
        status = ("❌ Some checks failed. Fix the effect and press Submit in Exit again (or run "
                  "`Exit --market submit`): it updates this issue and the checks run again. · 有检查没通过。"
                  "改好特效后在 Exit 里再点一次投稿（或再运行一次 `Exit --market submit`），会更新这个 issue 并重新检查。")
    comment = "\n\n".join(x for x in [
        "Thanks for the submission! · 感谢投稿！",
        f"![preview]({preview})" if preview else None,
        state["report"].strip(), status] if x)
    edited = subprocess.run(["gh", "issue", "comment", str(n), "--edit-last", "--body", comment],
                            capture_output=True, text=True).returncode == 0
    if not edited:
        gh("issue", "comment", str(n), "--body", comment)
    add, remove = (LABEL_OK, LABEL_FIX) if state["ok"] else (LABEL_FIX, LABEL_OK)
    gh("issue", "edit", str(n), "--add-label", f"{LABEL_SUBMISSION},{add}", "--remove-label", remove, check_=False)
    print(f"issue #{n}: {'ok' if state['ok'] else 'needs changes'}" + (f", PR #{pr}" if pr else "")
          + (" merged" if merged else ""))
    if not state["ok"]:
        sys.exit(1)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "read":
        read(sys.argv[2] if len(sys.argv) > 2 else os.environ["GITHUB_EVENT_PATH"])
    elif mode == "publish":
        publish(sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        sys.exit(__doc__)
