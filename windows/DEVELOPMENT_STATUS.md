# Listenote Daily Windows 开发状态

日期：2026-09-13

## 已完成

- Windows 系统托盘程序，使用学习图标和英文菜单。
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
- 单元测试：13 项运行，12 项通过，1 项按预期跳过。
- 跳过项是 Windows 系统简繁转换 API；workflow 会在 Windows Runner 再运行该项。
- 已覆盖时间窗边界、跨午夜配置、Markdown 时间、噪声阈值、错误转录后的音频删除和成功写入。

## 尚未验证

- 尚未在真实 Windows 麦克风上录音。
- 尚未执行 Windows 安装器和开机启动。
- 尚未生成正式 `.exe`；项目推送 GitHub 后由现成 workflow 构建。

以上三项属于 Windows 运行环境验收，不影响继续在 Mac 上开发代码。
