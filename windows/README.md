# Listenote Daily for Windows

Windows 本地中文持续转录工具。它按设定时间自动录音，用本地 Whisper 转成简体中文，并按日期写入 Markdown。音频只作为临时分片存在，处理完成或失败后都会删除；待处理队列最多保留 4 段，避免长期堆积。

> 当前为 Windows MVP。代码和安装包可在 macOS 上开发、由 GitHub Actions 构建，但麦克风、开机启动和系统托盘仍需在真实 Windows 电脑最终验收。

## 已实现

- Windows 系统托盘：极简学习图标，不在状态栏显示中文或“录音”字样。
- 每天多个可配置时间段；支持手动开始、停止和恢复自动计划。
- Windows `waveIn` 原生麦克风采集，不依赖 Python 录音包。
- 本地 `whisper.cpp` + Large v3 Turbo，固定中文 `zh`。
- Windows 内置简繁转换，按 `YYYY-MM-DD.md` 和准确时间段存储。
- 录音和转录并行，避免模型处理时中断下一段采集。
- 临时音频有上限，处理后立即删除；日志自动轮转。

## 构建 Windows 安装包

仓库推送到 GitHub 后，`build-windows` workflow 会在 Windows Runner 上完成测试和 PyInstaller 构建，生成：

```text
ListenoteDaily-Windows-x64.zip
```

也可在 Windows PowerShell 本地构建：

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-build.txt
python -m unittest discover -s tests -v
pyinstaller --noconfirm --clean --windowed --name ListenoteDaily --collect-all pystray --collect-all PIL main.py
Copy-Item scripts\install.ps1 dist\ListenoteDaily\install.ps1
Copy-Item scripts\doctor.ps1 dist\ListenoteDaily\doctor.ps1
Copy-Item config.ini dist\ListenoteDaily\config.ini
```

## 安装

1. 下载并解压 `ListenoteDaily-Windows-x64.zip`。
2. 右键 PowerShell，进入解压目录。
3. 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

安装器不要求管理员权限，会完成：

- 安装到 `%LOCALAPPDATA%\Listenote Daily`；
- 从 whisper.cpp 官方 GitHub Release 下载 Windows x64 CPU 版；
- 下载并校验约 1.5 GB 的 Large v3 Turbo 模型；
- 创建当前用户的开机启动快捷方式；
- 创建开始菜单快捷方式，退出后可搜索 `Listenote Daily` 重新打开；
- 保留已有配置、模型和 Markdown 记录。

## 使用

托盘图标为 macOS 同款折角文档样式，颜色即状态：绿色＝录音中，蓝色＝转写中，灰色＝空闲，红色＝出错。录音中为三段均衡条，暂停为两条竖线。图标悬停提示与菜单首行显示实时状态（已录时长 / 待处理段数 / 今日已存段数与分钟数）。

菜单文字语言由配置 `[ui] language` 控制，支持 `en`（默认）与 `zh`：

```ini
[ui]
language = zh
```

`zh` 菜单项：打开今日记录、打开记录文件夹、立即开始、停止、恢复时间表、设置、退出。菜单首行为只读状态，不可点击。

`Settings` 打开图形设置窗口（时间表、转写参数、界面语言），保存后数秒内自动生效，无需重启；窗口不可用时回退为用记事本打开 `config.ini`。

默认配置：

```ini
[schedule]
enabled = true
days = 1,2,3,4,5,6,7
windows = 09:00-12:00,13:30-18:00
```

修改 `%LOCALAPPDATA%\Listenote Daily\config.ini` 后无需重启，数秒内自动生效。时间窗结束时间不包含在录音范围内。

## 数据与隐私

- Markdown：`%LOCALAPPDATA%\Listenote Daily\records\transcripts`
- 日志：`%LOCALAPPDATA%\Listenote Daily\logs\listenote.log`
- 临时音频：`%LOCALAPPDATA%\Listenote Daily\temp`
- 音频和转录都只在本机处理，不调用云端语音 API。
- 安装时仅从 whisper.cpp 官方 GitHub Release 和 Hugging Face 官方模型仓库下载程序与模型。

## 自检

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\Listenote Daily\doctor.ps1"
```

开发机测试：

```bash
python3 -m unittest discover -s tests -v
python3 -m compileall -q listenote_win main.py
```
