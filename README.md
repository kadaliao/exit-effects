# Exit Effects

Window animations made by the community for [Exit](https://github.com/kadaliao/exit), the
macOS app that plays an effect where a window closes. Each effect is one Metal file.

**Browse them: <https://kadaliao.github.io/exit-effects/>** · [中文](README.zh-CN.md)

## Install

- **In Exit 0.3 or later:** Settings → Market. Try an effect on screen, then click
  **Install**. Installed effects update themselves; turn on *Install new effects
  automatically* to subscribe to new ones.
- **By hand:** download a `.metal` file from [effects/](effects/) into
  `~/Library/Application Support/Exit/Effects/`.

## Submit an effect

In Exit 0.4.0 or later, press **Submit** (the paper plane) on your effect in Settings →
Effects. Exit checks the effect on your Mac and opens a submission issue from your GitHub
account (sign in once with a code on github.com, or a signed-in GitHub CLI is used); a bot
checks it again, renders a preview and opens a pull request with you as the commit author,
and Exit shows its answer on the effect's card. To fix something, press Submit again and the
same issue is updated. Once the checks pass, the pull request is merged and the effect appears in
everyone's market within minutes.

An effect's file name is its name in the market, and it belongs to the GitHub account that first
submitted it. To update your effect, submit it again under the same file name.

Coding agents can do the same: ask Claude Code, Codex, … *"Submit my Paper Plane effect to
the Exit market."* [AGENTS.md](AGENTS.md) tells it to run `Exit --market submit <effect> --wait`.

A pull request that adds `effects/<id>.metal` works too; it's merged after a review.

### What the checks look for

| Check | Rule |
|---|---|
| File name | `effects/<id>.metal`; 2–40 lowercase letters, digits and dashes; not the name of a built-in effect |
| Header | `// @name`, `// @description` and `// @author` (the bot adds your GitHub name if `@author` is missing). `@name.zh` and `@description.zh` are welcome |
| Compiles | with the Exit release in [`.exit-version`](.exit-version) |
| Start and finish | the first frame is exactly the untouched window and the last is fully transparent; opening effects start and end transparent and only add light |
| Speed | at most 20 ms per Retina frame on GitHub's macOS runner, which is about four times slower than an Apple-silicon Mac (the slowest built-in effect takes about 16 ms there) |
| Size | at most 32 KB, no `#include` |
| Name | not the name of someone else's effect in the market (your own: that's an update) |
| Original | not the same code as another effect; a copy with other comments or numbers counts as the same |

Run them yourself before submitting:

```sh
Exit.app/Contents/MacOS/Exit --validate --only my-effect
```

or, in a clone of this repository, `scripts/get-exit.sh && python3 scripts/check.py effects/my-effect.metal`.

By submitting you confirm you wrote the effect (or may share it) and release it under the
[MIT License](LICENSE).

## How it works

| | |
|---|---|
| [`submission.yml`](.github/workflows/submission.yml) | turns a submission issue from `Exit --market submit` into a checked pull request, with the preview in the comment, and merges it when the checks pass |
| [`check.yml`](.github/workflows/check.yml) | checks effects changed by a pull request |
| [`publish.yml`](.github/workflows/publish.yml) | on every merge: builds `index.json`, renders previews for new or changed effects and publishes the site to the `gh-pages` branch |

The site is served by GitHub Pages and mirrored by jsDelivr
(`https://cdn.jsdelivr.net/gh/kadaliao/exit-effects@gh-pages/`), which Exit falls back to
when GitHub is unreachable. Every file in `index.json` carries a SHA-256 that Exit checks
before installing.

### Run your own market

Exit can read any number of markets (Settings → Market → Sources). A market is a web
folder with an `index.json` like [this one](https://kadaliao.github.io/exit-effects/index.json):

```json
{
  "format": 1,
  "name": "My Effects",
  "mirrors": ["https://another.host/same/folder/"],
  "effects": [
    {
      "id": "blinds",
      "name": "Blinds",
      "name_zh": "百叶窗",
      "description": "The window turns into slats that flip shut one after another.",
      "author": "Kada Liao",
      "owner_id": 7401626,
      "events": ["close", "quit", "minimize"],
      "duration": 0.75,
      "requires": "0.3",
      "file": "effects/blinds.metal",
      "preview": "previews/blinds-1575759c.gif",
      "sha256": "1575759cb55eb9a845da6865325a1e6048236117235ec19e19a5d3ca50339f27"
    }
  ]
}
```

`file` and `preview` are relative to the folder. `owner_id` is optional: the GitHub account that
submitted the effect, so Exit's Submit sheet can tell an update from a taken name.

Fork this repository to reuse the checks and the publishing: the scripts follow the repository
they run in (change the links in `site/index.html`, `AGENTS.md` and `MarketSubmit.repo` in Exit),
then enable GitHub Pages on the `gh-pages` branch.
