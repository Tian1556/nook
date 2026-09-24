# Nook 私人版实施计划

## 实施原则

- 在 `nook-main` 分支上工作，基线为 Noty `v1.9.2`。
- 先建立可自动检查的身份常量，再做机械替换，最后构建与运行验证。
- 保留 `noty-id`、`noty-img` 等存档与 Markdown 内部格式标识，避免无必要的数据格式分叉。
- 保留上游 MIT 与第三方许可；移除 Sparkle 运行依赖，但不删除历史许可说明。

## 任务 1：建立基线

1. 运行现有编辑器、同步及本地化测试脚本。
2. 以 debug 模式构建原始 `v1.9.2`，记录基线是否通过。
3. 若基线失败，先区分环境问题与代码问题，不把上游缺陷混入品牌改造。

## 任务 2：应用身份独立

修改 `Info.plist`：

- `CFBundleName`、`CFBundleDisplayName`、`CFBundleExecutable` → `Nook`
- `CFBundleIdentifier`、URL Name → `local.nook.Nook`
- URL Scheme → `nook`
- 删除 `SUFeedURL` 与 `SUPublicEDKey`

修改 `build.sh`：

- 输出 `build/Nook.app`
- 二进制与临时目录改为 Nook 命名
- 删除 Sparkle 探测、链接、复制、签名和 Intel appcast 分支
- 运行模式只关闭并启动 Nook

## 任务 3：数据与自动化隔离

修改运行时代码：

- Application Support 目录改为 `Nook`
- 设置域后备值改为 `local.nook.Nook`
- iCloud Drive 同步目录改为 `Nook`
- URL Scheme 路由只接受 `nook://`
- 窗口标题、导出元数据和可见提示改为 Nook

保留以下兼容标识：

- Markdown 图片协议 `noty-img://`
- 同步文档 front matter 字段 `noty-id`
- Swift 内部类型名和属性名（如 `NotyMain`、`notyHidden`），除非它们会出现在用户界面或系统注册信息中

## 任务 4：彻底关闭官方更新

- 删除应用启动时的 Updater 初始化。
- 删除主菜单与边缘菜单的“检查更新”和“自动更新”入口。
- 删除设置窗口的更新标签页及其状态模型。
- 不编译 `Updater.swift`；保留源文件作为上游历史亦可，但构建必须明确排除。
- 增加静态检查，确保构建产物不含原 appcast URL、公钥或 Sparkle 动态依赖。

## 任务 5：品牌文案与图标

- 更新中英文用户可见文案为 Nook。
- README 改为私人版说明，注明基于 Noty `v1.9.2`、MIT 来源和本地构建方式。
- 创建极简 Nook 图标：安静的私人角落意象，避免沿用 Noty 标识。
- 保留原项目许可证与第三方许可内容，不把上游版权替换为个人版权。

## 任务 6：测试与验收

1. 更新受品牌与 Bundle ID 影响的测试期望。
2. 运行全部现有测试。
3. debug 构建 `Nook.app` 并验证代码签名。
4. 检查产物的名称、Bundle ID、可执行文件和 URL Scheme。
5. 检查产物不链接 Sparkle，且不含上游 appcast、公钥。
6. 运行应用并验证能创建独立的 Nook 数据目录。
7. 扫描用户可见资源中的 Noty 残留；允许许可证、来源说明和内部兼容格式保留。

## 提交策略

- 提交一：实施身份、存储、协议和更新隔离。
- 提交二：完成品牌文案、图标和 README。
- 提交三：补充验证脚本或测试并记录最终验收结果。
