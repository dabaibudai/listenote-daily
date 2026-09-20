# 仓库结构

本仓库按平台代码与共用能力分开：

```text
macos/                         macOS 应用、安装器、运行时和测试
windows/                       Windows 应用、安装器和测试
skills/listenote-daily-review/ 两个平台共用的录音复盘 Skill
docs/                          架构及开发状态文档
scripts/bootstrap.sh           兼容旧版 macOS 一键安装地址
```

## 边界

- `macos/` 与 `windows/` 可各自开发、测试和打包，不互相引用平台代码。
- `skills/` 只读取生成的 Markdown，不参与录音和转录。
- 模型、用户录音、转录、日志和本机配置不进入 Git 仓库。
- 根目录只保留总览、许可证、第三方声明和兼容入口。
