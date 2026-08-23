# Whisper Daily

macOS 本地中文持续转录工具。它在指定时间自动工作，把识别结果按日期写入 Markdown；音频片段只在处理时临时存在，成功后立即删除。

## 最终效果

- 完全本地：使用 `whisper.cpp` 的 Medium 多语言模型，不调用云端 API。
- 中文固定为 `zh`，保存前使用 macOS 内置能力转成简体中文。
- 每天一个 `YYYY-MM-DD.md`，每段保留本地起止时间，Codex 可直接检索。
- 菜单栏只显示冥想小人和计时，不出现中文或“录音”字样。
- 时间表由配置文件控制，不依赖 Codex、ChatGPT 或定时对话。
- 支持 Intel 与 Apple Silicon Mac。

## 一条命令安装

在新 Mac 的“终端”里运行：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dabaibudai/whisper-daily/main/scripts/bootstrap.sh)"
```

安装器会：

1. 缺少 Homebrew 时自动安装 Homebrew。
2. 安装 `sox`、`jq`、`ripgrep` 和 `whisper.cpp`。
3. 下载 Medium 模型（约 1.4GB）及 VAD 模型，并校验 SHA-256。
4. 安装状态栏程序、后台任务与可编辑时间表。

模型不会放进 GitHub。安装通常需要几分钟，主要取决于 1.4GB 模型的下载速度。

## 第一次测试

安装结束后运行：

```bash
whisper-daily start
```

macOS 询问麦克风权限时选择“允许”。清晰说一段 20–30 秒中文，等待约半分钟，再运行：

```bash
whisper-daily notes
```

测试完成后执行：

```bash
whisper-daily stop
```

`start` 是手动覆盖，会持续运行，直到执行 `stop`；正常日常使用由时间表自动控制。

## 配置时间表

默认配置就是每天两个时段：

```ini
ENABLED=1
DAYS=1,2,3,4,5,6,7
WINDOWS=09:00-12:00,13:30-18:00
MODEL_SIZE=medium
LANGUAGE=zh
```

打开配置：

```bash
whisper-daily config
```

- `ENABLED=0`：关闭自动时间表，仅允许手动启动。
- `DAYS=1,2,3,4,5`：仅周一至周五。
- `WINDOWS`：可写一个或多个本地时间区间，用英文逗号分隔。

保存后最多 60 秒生效，不需要重启，也不需要 Codex。

## 常用命令

```bash
whisper-daily start                     # 立即开始，手动覆盖时间表
whisper-daily stop                      # 暂停到下一个自动时段
whisper-daily status                    # 查看进程和时间表
whisper-daily notes                     # 打开记录目录
whisper-daily config                    # 编辑时间表
whisper-daily search "关键词" 2026-08-23 # 按日期搜索
whisper-daily doctor                    # 检查依赖、模型和进程
```

## 文件位置

实际数据保存在 macOS 允许后台访问的位置：

```text
~/Library/Application Support/WhisperDaily/
├── config/schedule.conf
├── models/
└── records/
    ├── transcripts/YYYY-MM-DD.md
    └── logs/
```

安装器还会创建方便访问的链接：

```text
~/WhisperDaily Records
```

单段 Markdown 示例：

```markdown
## 09:15:02–09:15:28

这是转录后的简体中文。

<!-- start: 2026-08-23T09:15:02-0700 | end: 2026-08-23T09:15:28-0700 | duration: 26.0 | model: local:ggml-medium.bin -->
```

## 隐私与磁盘

- 语音、模型和文字都留在本机。
- 每个片段转录完成后，临时 MP3 会删除；异常断电最多可能留下当前片段。
- Git 仓库通过 `.gitignore` 排除模型、记录、日志和 PID 文件。
- Medium 模型约 1.4GB；长期增长的主要是 Markdown 文本，不是音频。

## 故障排查

先运行：

```bash
whisper-daily doctor
whisper-daily status
```

如果没有文字：

1. 在“系统设置 → 隐私与安全性 → 麦克风”允许终端、SoX/`rec` 的权限。
2. 清晰说满 20–30 秒，随后等待一个处理周期。
3. 查看 `~/WhisperDaily Records/logs/` 中当天的 runtime 日志。

如果状态栏未出现，可直接打开：

```bash
open "$HOME/Applications/WhisperDaily.app"
```

## 卸载

```bash
/bin/zsh "$HOME/Library/Application Support/WhisperDaily/scripts/uninstall.sh"
```

卸载内容会移入废纸篓，便于恢复；Homebrew 依赖不会删除，因为它们可能被其他程序共用。

## 开源说明

本项目使用 MIT License。转录采集脚本基于 `yohasebe/whisper-stream` 3.1.2 修改，其原始 MIT License 保留在 `vendor/whisper-stream/LICENSE`。
