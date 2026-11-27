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

1. Write one with the [authoring guide](https://github.com/kadaliao/exit/blob/main/docs/EFFECTS.md),
   or let Exit's AI write it (Settings → Create with AI).
2. Send it in, whichever way suits you:
   - **From Exit:** click **Submit** on the effect's card in Settings → Effects. Exit checks
     it, copies the code and opens the submission form.
   - **[Open a submission](https://github.com/kadaliao/exit-effects/issues/new?template=submit-effect.yml)**
     and paste the code.
   - **A pull request** that adds `effects/<id>.metal`.
3. A bot checks it, renders a preview and replies within a few minutes. For submissions it
   opens the pull request itself, with you as the commit author. Edit the issue to fix
   anything; the checks run again. After a review it's merged and appears in everyone's
   market.

### What the checks look for

| Check | Rule |
|---|---|
| File name | `effects/<id>.metal`; 2–40 lowercase letters, digits and dashes; not the name of a built-in effect |
| Header | `// @name`, `// @description` and `// @author` (the bot adds your GitHub name if `@author` is missing). `@name.zh` and `@description.zh` are welcome |
| Compiles | with the Exit release in [`.exit-version`](.exit-version) |
| Start and finish | the first frame is exactly the untouched window and the last is fully transparent; opening effects start and end transparent and only add light |
| Speed | at most 20 ms per Retina frame on GitHub's macOS runner, which is about four times slower than an Apple-silicon Mac (the slowest built-in effect takes about 16 ms there) |
| Size | at most 32 KB, no `#include` |

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
| [`submission.yml`](.github/workflows/submission.yml) | turns a submission issue into a checked pull request, with the preview in the comment |
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

`file` and `preview` are relative to the folder. Fork this repository to reuse the checks
and the publishing: the scripts follow the repository they run in (change the links in
`site/index.html` and the issue form), then enable GitHub Pages on the `gh-pages` branch.
