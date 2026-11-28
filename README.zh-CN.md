# Exit 特效市场

社区为 [Exit](https://github.com/kadaliao/exit)（在窗口关闭处播放特效的 macOS App）做的
窗口特效，每个都是一个 Metal 文件。

**在线浏览：<https://kadaliao.github.io/exit-effects/>** · [English](README.md)

## 安装

- **Exit 0.3 及以上：** 设置 → 特效市场。先在屏幕上试玩，再点**安装**。装好的特效会自动
  更新；勾选“自动安装新上架的特效”就是订阅，以后的新特效会自己装上。
- **手动：** 从 [effects/](effects/) 下载 `.metal` 文件，放进
  `~/Library/Application Support/Exit/Effects/`。

## 投稿

在 Exit 0.4.0 及以上版本里，打开“设置 → 特效”，点你的特效上的**投稿**按钮（纸飞机）。Exit 会先在你的
Mac 上检查特效，再用你的 GitHub 账号提交一个投稿 issue（第一次在 github.com 上输入验证码登录，已登录
GitHub CLI 的话直接用它）；机器人会再检查一遍、渲染预览，并以你为提交作者自动开 PR，结果显示在特效卡片上。
要修改的话，再点一次投稿，会更新同一个 issue。检查通过后 PR 会自动合并，几分钟内所有人的特效市场里都会出现它。

文件名就是特效在市场里的名字，它属于第一个投稿这个名字的 GitHub 账号。要更新自己的特效，用同一个文件名再投一次。

coding agent 也能代劳：对 Claude Code、Codex 等说 *“把我的 Paper Plane 特效投稿到 Exit 特效市场。”*
[AGENTS.md](AGENTS.md) 会让它运行 `Exit --market submit <特效> --wait`。

也可以直接提 PR，新增 `effects/<id>.metal`。

### 检查哪些东西

| 检查 | 要求 |
|---|---|
| 文件名 | `effects/<id>.metal`；2–40 个小写字母、数字或短横线；不能和内置特效重名 |
| 头部 | `// @name`、`// @description`、`// @author`（没写 `@author` 时机器人会填上你的 GitHub 用户名）。欢迎加上 `@name.zh` 和 `@description.zh` |
| 编译 | 用 [`.exit-version`](.exit-version) 里的 Exit 版本编译 |
| 首尾帧 | 第一帧和原窗口一模一样，最后一帧完全透明；打开特效首尾都透明，只叠加光效 |
| 性能 | 在 GitHub 的 macOS runner 上每个 Retina 帧不超过 20 毫秒（runner 比 Apple 芯片的 Mac 慢约 4 倍，最慢的内置特效在上面约 16 毫秒） |
| 大小 | 不超过 32 KB，不能 `#include` |
| 名字 | 不能和市场里别人的特效同名（和自己的同名就是更新） |
| 原创 | 代码不能和市场里已有的特效相同；只改了注释或数字的也算相同 |

投稿前可以自己先跑一遍：

```sh
Exit.app/Contents/MacOS/Exit --validate --only my-effect
```

或者在本仓库的克隆里运行 `scripts/get-exit.sh && python3 scripts/check.py effects/my-effect.metal`。

投稿即表示这个特效是你写的（或你有权分享），并同意以 [MIT 许可证](LICENSE)发布。

## 工作原理

| | |
|---|---|
| [`submission.yml`](.github/workflows/submission.yml) | 把投稿 issue 变成检查过的 PR，评论里附预览图；检查通过就合并 |
| [`check.yml`](.github/workflows/check.yml) | 检查 PR 改动的特效 |
| [`publish.yml`](.github/workflows/publish.yml) | 每次合并后生成 `index.json`、为新增或修改的特效渲染预览，并把站点发布到 `gh-pages` 分支 |

站点由 GitHub Pages 提供，jsDelivr 做镜像（`https://cdn.jsdelivr.net/gh/kadaliao/exit-effects@gh-pages/`），
GitHub 连不上时 Exit 会自动改用镜像。`index.json` 里每个文件都带 SHA-256，Exit 安装前会校验。

### 自己开一个市场

Exit 可以同时读多个市场（设置 → 特效市场 → 来源）。一个市场就是一个网站目录，里面放一份
格式和[官方这份](https://kadaliao.github.io/exit-effects/index.json)相同的 `index.json`，
格式说明见[英文版](README.md#run-your-own-market)。fork 本仓库就能直接用上全套检查和发布流程。
