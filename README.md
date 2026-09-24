# Nook

Nook 是一个只属于自己的 macOS 屏幕边缘便笺工具。它基于
[aimen08/noty](https://github.com/aimen08/noty) `v1.9.2`，以 MIT License
授权，并针对私人使用完成了独立化。

## 与 Noty 的隔离

- 独立应用名：`Nook.app`
- 独立 Bundle ID：`local.nook.Nook`
- 独立数据目录：`~/Library/Application Support/Nook/`
- 独立自动化协议：`nook://`
- 不连接 Noty 的自动更新服务

Nook 与 Noty 可以同时安装和运行，不会共用笔记、偏好设置或自动化入口。

## 主要能力

- 便笺停靠在屏幕边缘，需要时展开
- 快速记录、全局快捷键和任务勾选
- Markdown 即时样式
- 本地 SQLite 存储，正文使用 AES-GCM 加密
- Markdown、纯文本和 `.stickies` 导入导出

为保持存档兼容性，内部 Markdown 图片协议 `noty-img://` 沿用上游格式。
它不是应用品牌或系统注册协议。

## 构建

需要 macOS 15 或更高版本。完整 Xcode 能提供 SwiftUI 所需的宏插件；仅安装
Command Line Tools 的某些版本可能缺少 `SwiftUIMacros`，从而无法编译。

```bash
./build.sh debug
open build/Nook.app
```

发布模式会生成通用架构应用：

```bash
MARKETING_VERSION=1.9.2 BUILD_NUMBER=192 ./build.sh
```

## 自动化

```bash
open "nook://new?text=Buy%20milk"
open "nook://capture"
open "nook://all"
open "nook://settings"
```

URL 中的文本只会成为笔记内容，不会被执行。

## 数据说明

Nook 首次启动时创建新的数据库和加密密钥，不会自动读取或迁移 Noty 数据。
所有笔记只保存在本机；Nook 不连接 iCloud，也不把笔记发送到云端。
若以后需要迁移，请优先通过 Noty 的导出功能和 Nook 的导入功能完成，不要直接
复制 `notes.db` 或 `note.key`。

## 来源与许可

原始项目版权归 Aymen Hamza 及相应贡献者所有。本私人版本保留根目录中的
`LICENSE` 和 `licenses/THIRD-PARTY.txt`。Nook 的修改不会改变上游代码的版权归属。
