# Listenote Daily

本地中文持续转录工具。它按时间表自动工作，用本地 Whisper 将语音写入每日 Markdown；音频只作临时分片，处理后删除。

## 选择平台

| 平台 | 状态 | 安装与说明 |
|---|---|---|
| macOS | 已完成本机安装与录音测试 | [`macos/README.md`](macos/README.md) |
| Windows x64 | `v0.2.0 Preview` | [`windows/README.md`](windows/README.md) · [下载安装包](https://github.com/dabaibudai/listenote-daily/releases/tag/windows-v0.2.0) |
| 录音复盘 Skill | Mac/Windows 共用 | [`skills/listenote-daily-review/`](skills/listenote-daily-review/) |

## macOS 一键安装

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dabaibudai/listenote-daily/main/scripts/bootstrap.sh)"
```

旧安装地址继续保留；它会转交给 `macos/scripts/bootstrap.sh`。

## Windows 安装

1. 下载并解压 [`ListenoteDaily-Windows-x64.zip`](https://github.com/dabaibudai/listenote-daily/releases/download/windows-v0.2.0/ListenoteDaily-Windows-x64.zip)。
2. 在解压目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Windows 版提供中英文托盘菜单、图形设置、四种状态图标、录音时长和今日记录统计。

## 仓库结构

```text
listenote-daily/
├── macos/                         # Mac 应用、安装器、运行时与测试
├── windows/                       # Windows 应用、安装器与测试
├── skills/listenote-daily-review/ # 共用录音复盘 Skill
├── docs/                          # 架构与开发状态
├── scripts/bootstrap.sh           # 兼容旧 Mac 安装地址
└── .github/workflows/             # Mac CI 与 Windows 构建
```

## 共同原则

- 完全本地转录，不调用云端语音 API。
- 默认使用 Large v3 Turbo 中文模型。
- 每天一个 `YYYY-MM-DD.md`，每段保留本地起止时间。
- 临时音频不会长期保存，主要磁盘占用来自模型。
- 时间表由本机配置文件控制，不依赖 Codex 或定时对话。

## 用 AI 复盘录音

`skills/listenote-daily-review` 可按日期或时间段检索 Markdown，生成详细录音复盘。Mac 完整安装会自动安装该 Skill；也可单独运行：

```bash
/bin/zsh macos/scripts/install-review-skill.sh
```

## 开发

- Mac 测试：`/bin/zsh macos/tests/test.sh`
- Windows 测试：`cd windows && python -m unittest discover -s tests -v`
- Windows 安装包由 `.github/workflows/build-windows.yml` 构建。

本项目使用 MIT License。第三方依赖说明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
