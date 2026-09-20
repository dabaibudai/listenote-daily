# Listenote Daily Windows 开发状态

日期：2026-09-19

## 已完成

- Windows 系统托盘程序，使用四种状态图标和中英文菜单。
- 图形设置窗口、录音时长、待处理段数和今日记录统计。
- Windows 原生 `waveIn` 麦克风采集，默认共享系统麦克风。
- 录音与转录双线程并行，转录期间继续采集下一段。
- 待处理音频最多 4 段；成功、失败和下次启动时都会清理临时音频。
- 本地 whisper.cpp + Large v3 Turbo，固定中文识别。
- Windows 内置简体中文转换。
- 按日期生成 Markdown，并保存每段开始、结束时间及模型元数据。
- 支持每天多个时间窗、手动开始、停止和恢复计划。
- 安装器自动下载并校验模型、下载官方 whisper.cpp、保留已有配置和记录。
- 当前用户开机启动和开始菜单快捷方式。
- GitHub Actions 自动测试并构建 `ListenoteDaily-Windows-x64.zip`。

## 本机验证

- Python 语法检查：通过。
- 单元测试：16 项通过，包括 Windows 系统简繁转换 API。
- Mac CI 与 Windows 构建 workflow：通过。
- 已覆盖时间窗边界、跨午夜配置、Markdown 时间、噪声阈值、错误转录后的音频删除和成功写入。
- Windows x64 安装包已生成并发布为 `windows-v0.2.0` 预览版。

## 后续验收

- 首次在新的 Windows 电脑安装时，仍建议检查麦克风权限、默认输入设备和开机启动。
- 预览版稳定后再改为正式 Release。
