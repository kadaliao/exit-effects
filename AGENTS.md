# Submitting an effect to the Exit market — guide for coding agents

You are helping someone share an [Exit](https://github.com/kadaliao/exit) effect. Exit is a
macOS app that plays a Metal shader where a window closes (or opens). This repository is
its community market: every effect here is one `.metal` file, and it reaches every Exit
user's Settings → Market as soon as it passes the checks. People submit with the Submit button in Exit, or
they ask you, and you use the one command below.

## What you need

- **Exit 0.3.1 or later.** The binary is `/Applications/Exit.app/Contents/MacOS/Exit`
  (if it isn't there: `mdfind 'kMDItemCFBundleIdentifier == io.github.kadaliao.Exit'`).
  `Exit --version` prints the version; `brew upgrade --cask exit` updates it.
- **A GitHub sign-in.** Either the GitHub CLI is signed in (`gh auth status`), or the person
  signed in to GitHub inside Exit 0.4.0 or later (Settings → Effects → the paper-plane
  button on one of their effects → Sign in with GitHub); the command uses whichever exists.
  If neither, ask the person to do one of the two themselves; never handle their credentials.
- **The effect.** People's own effects live in `~/Library/Application Support/Exit/Effects/`.
  `Exit --check` lists every effect Exit knows with its id. You can pass an id or a path.

In the commands below, `Exit` means the full path to the binary.

## Before you submit

1. **Ask.** Confirm which effect, and that the person wrote it (or may share it) and agrees
   to publish it under the [MIT License](LICENSE). Submitting posts the code in a public
   GitHub issue from their account.
2. **Check the header.** The file starts with `// @key value` lines. The market needs
   `@name` and `@description` (one sentence about what the window does). Add `@author` with
   the name they want shown; without it the bot uses their GitHub user name. If you can,
   add `@name.zh` and `@description.zh` in Chinese.
3. **Check the effect.** `Exit --validate --only <id>` compiles it and checks that the
   first frame is exactly the untouched window, the last frame is fully transparent, and it
   is fast enough. `Exit --render-sheet /tmp/<id>.png --only <id>` renders a strip of frames
   you can look at.

The market's rules:

| | |
|---|---|
| File name | 2–40 lowercase letters, digits and dashes (`paper-plane.metal`); not the name of an effect built into Exit |
| Header | `@name` and `@description`; `@author` recommended |
| Start and finish | closing effects start as the untouched window and end fully transparent; `@events open` effects start and end transparent and only add light |
| Speed | at most 20 ms per Retina frame on GitHub's macOS runner (about 5 ms on an Apple-silicon Mac) |
| Size | at most 32 KB, no `#include` / `#import` |
| Name | the file name is the effect's name in the market and belongs to the GitHub account that first submitted it; someone else's name fails, your own is an update |
| Originality | the person's own work, not a copy of another app's effect; the same code as an effect in the market fails, even with other comments or numbers |

How to write or fix an effect: the [authoring guide](https://raw.githubusercontent.com/kadaliao/exit/main/docs/EFFECTS.md).

## Submit

```sh
Exit --market submit <id or path/to/effect.metal> --wait
```

It runs the checks above on this Mac, then opens an issue in this repository from the
person's GitHub account.
The market's bot checks the effect again on a GitHub runner, renders a preview and opens a
pull request with the person as commit author. `--wait` stays until the bot answers (about
five minutes) and prints its report.

| Option | |
|---|---|
| `--notes "…"` | a message for the reviewer |
| `--dry-run` | print the issue instead of sending it |
| `--force` | send it even though the local checks fail, to get the bot's report |

Exit status: `0` sent (with `--wait`: the bot accepted it), `1` something needs fixing (the
reasons are printed), `2` the effect or the arguments weren't found.

## After you submit

- **The bot found problems:** fix the file and run the same command again. It updates the
  same issue and the checks run again. Don't open a new issue or pull request by hand.
- **Accepted:** the bot merges the pull request, and the effect is on
  <https://kadaliao.github.io/exit-effects/> and in everyone's Settings → Market within
  minutes. Tell the person the issue link.
- **An update to an effect that's already in the market:** submit the new version the same
  way, under the same file name and from the same GitHub account; the pull request replaces
  the old file.
- **"Name" failed:** someone else's effect has that file name. Rename the file (and its
  `@name`) and submit again. **"Original" failed:** the code is already in the market;
  don't resubmit it under another name.

Prefer a pull request? Add `effects/<id>.metal` to a fork and open one; the same checks run,
but the maintainer merges it by hand. The command above is quicker and gives you the report directly.
