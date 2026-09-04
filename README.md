# Listenote Daily

macOS 本地中文持续转录工具。它在指定时间自动工作，把识别结果按日期写入 Markdown；音频片段只在处理时临时存在，成功后立即删除。

## 最终效果

- 完全本地：使用 `whisper.cpp` 的 Large v3 Turbo 多语言模型，不调用云端 API。
- 中文固定为 `zh`，保存前使用 macOS 内置能力转成简体中文。
- 每天一个 `YYYY-MM-DD.md`，每段保留本地起止时间，Codex 可直接检索。
- 菜单栏只显示冥想小人和计时，不出现中文或“录音”字样。
- 时间表由配置文件控制，不依赖 Codex、ChatGPT 或定时对话。
- 支持 Intel 与 Apple Silicon Mac。

## 一条命令安装

在新 Mac 的“终端”里运行：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dabaibudai/listenote-daily/main/scripts/bootstrap.sh)"
```

安装器会：

1. 缺少 Homebrew 时自动安装 Homebrew。
2. 安装 `sox`、`jq`、`ripgrep` 和 `whisper.cpp`。
3. 下载 Large v3 Turbo 模型（约 1.5GB）及 VAD 模型，并校验 SHA-256。
4. 安装状态栏程序、后台任务与可编辑时间表。
5. 安装独立的 `listenote-daily-review` skill；已有同名 skill 保留不覆盖。

模型不会放进 GitHub。安装通常需要几分钟，主要取决于 1.4GB 模型的下载速度。

## 第一次测试

安装结束后运行：

```bash
listenote-daily start
```

macOS 询问麦克风权限时选择“允许”。清晰说一段 20–30 秒中文，等待约半分钟，再运行：

```bash
listenote-daily notes
```

测试完成后执行：

```bash
listenote-daily stop
```

`start` 是手动覆盖；执行 `stop` 会立即停止。若保持运行，到达 `WINDOWS` 中任一时间段的结束时间时也会自动停止，避免手动录音整夜运行。

## 配置时间表

默认配置就是每天两个时段：

```ini
ENABLED=1
DAYS=1,2,3,4,5,6,7
WINDOWS=09:00-12:00,13:30-18:00
MODEL_SIZE=large-v3-turbo
LANGUAGE=zh
```

打开配置：

```bash
listenote-daily config
```

- `ENABLED=0`：关闭自动时间表，仅允许手动启动。
- `DAYS=1,2,3,4,5`：仅周一至周五。
- `WINDOWS`：可写一个或多个本地时间区间，用英文逗号分隔。

保存后最多 60 秒生效，不需要重启，也不需要 Codex。

## 常用命令

```bash
listenote-daily start                     # 立即开始，手动覆盖时间表
listenote-daily stop                      # 暂停到下一个自动时段
listenote-daily status                    # 查看进程和时间表
listenote-daily notes                     # 打开记录目录
listenote-daily config                    # 编辑时间表
listenote-daily search "关键词" 2026-08-23 # 按日期搜索
listenote-daily doctor                    # 检查依赖、模型和进程
```

## 文件位置

实际数据保存在 macOS 允许后台访问的位置：

```text
~/Library/Application Support/Listenote Daily/
├── config/schedule.conf
├── models/
└── records/
    ├── transcripts/YYYY-MM-DD.md
    └── logs/
```

安装器还会创建方便访问的链接：

```text
~/Listenote Daily Records
```

单段 Markdown 示例：

```markdown
## 09:15:02–09:15:28

这是转录后的简体中文。

<!-- start: 2026-08-23T09:15:02-0700 | end: 2026-08-23T09:15:28-0700 | duration: 26.0 | model: local:ggml-large-v3-turbo.bin -->
```

## 用 AI 复盘录音

仓库的 `skills/listenote-daily-review` 包含完整复盘规则和 Python 3 标准库定位脚本，不依赖飞书 skill、账号或 `lark-cli`。总结由运行 skill 的 AI 完成，脚本本身只定位原始文件。

完整安装会把 skill 放到 `${CODEX_HOME:-~/.codex}/skills/listenote-daily-review`。仅下载源码时，可在仓库根目录单独运行（不会启动录音或下载模型）：

```bash
/bin/zsh scripts/install-review-skill.sh
```

在 Codex 中让它“使用 $listenote-daily-review 复盘昨天的录音”即可。默认自动找到当前用户的 `~/Library/Application Support/Listenote Daily/records/transcripts`，无需手改用户名，兼容旧版 WhisperDaily。

首次可验证目录：

```bash
python3 skills/listenote-daily-review/scripts/find_transcript.py --check --json
```

如果记录放在自定义位置，直接把路径告诉 AI，或使用 `--transcripts-dir` / `LISTENOTE_TRANSCRIPTS_DIR`；也识别运行时的 `LISTENOTE_DAILY_ROOT`。显式指定目录时不会回退到其他位置。

摘要输出到当前工作区，先读已有摘要并保留用户修改；缺失日期明确报错，不复用其他日期。定时复盘需用户另外设置，本安装器不会创建 AI 定时任务。已有同名 skill 不自动升级，更新前应先比较和保留本地修改。

## 隐私与磁盘

- 语音、模型和文字都留在本机。
- 使用 AI 复盘时，读取的文字会进入所用 AI 的会话处理；这与完全本地的录音转写不同。仓库只分发 skill，不包含个人转录、摘要或用户配置。
- 每个片段转录完成后，临时 MP3 会删除；异常断电最多可能留下当前片段。
- Git 仓库通过 `.gitignore` 排除模型、记录、日志和 PID 文件。
- Large v3 Turbo 模型约 1.5GB；长期增长的主要是 Markdown 文本，不是音频。

## 故障排查

先运行：

```bash
listenote-daily doctor
listenote-daily status
```

如果没有文字：

1. 在“系统设置 → 隐私与安全性 → 麦克风”允许终端、SoX/`rec` 的权限。
2. 清晰说满 20–30 秒，随后等待一个处理周期。
3. 查看 `~/Listenote Daily Records/logs/` 中当天的 runtime 日志。

如果状态栏未出现，或者点击了 `Hide Status`，可运行下面的命令重新显示：

```bash
open "$HOME/Applications/Listenote Daily.app"
```

## 卸载

```bash
/bin/zsh "$HOME/Library/Application Support/Listenote Daily/scripts/uninstall.sh"
```

卸载内容会移入废纸篓，便于恢复；Homebrew 依赖不会删除，因为它们可能被其他程序共用。

## 开源说明

本项目使用 MIT License。转录采集脚本基于 `yohasebe/whisper-stream` 3.1.2 修改，其原始 MIT License 保留在 `vendor/whisper-stream/LICENSE`。
