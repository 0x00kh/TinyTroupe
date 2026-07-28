# TinyTroupe Agent Guide

本文件适用于整个仓库。修改代码前先阅读相关实现和测试，并保留工作区中已有
但与当前任务无关的改动。

## 项目概览

TinyTroupe 是一个使用 Swift 6 编写的原生 macOS 菜单栏动画应用，最低支持
macOS 13。项目使用 Swift Package Manager，不依赖第三方包，也不在运行时请求
网络资源。

- `Sources/RunnerCore/`：动画模型、帧数据、时间线和像素渲染，可独立测试。
- `Sources/TinyTroupe/`：AppKit/SwiftUI 应用入口、菜单栏项目和状态管理。
- `Tests/RunnerCoreTests/`：时间线、帧边界、渲染和配置序列化测试。
- `Assets/`：应用图标等仓库内资源。
- `Packaging/Info.plist`：应用元数据、最低系统版本和发布版本号。
- `scripts/`：App 与 DMG 构建脚本。
- `.github/workflows/`：双架构安装包构建与 GitHub Release 发布流程。

## 常用命令

```sh
swift test
swift run TinyTroupe
./scripts/build-app.sh x86_64
./scripts/build-app.sh arm64
./scripts/build-app.sh universal
./scripts/package-dmg.sh
```

`.build/` 和 `dist/` 是生成目录，不要提交其中的内容。

## 实现约束

- 保持应用为菜单栏 accessory app。不要无意中增加 Dock 图标或普通主窗口；
  `Packaging/Info.plist` 中的 `LSUIElement` 必须保持为 `true`。
- AppKit UI、`NSImage` 渲染、状态栏更新和 `ServiceManagement` 操作必须留在
  `@MainActor` 隔离范围内。
- 动画间隔统一由 `RunnerTimeline.frameDuration` 定义。修改节拍时同时更新纳秒值
  和相应测试，避免出现两套时间来源。
- 尊重“减少动态效果”系统设置：首次创建和恢复角色时，不应强制播放动画。
- 至少保留一个菜单栏角色，不要允许删除最后一个角色。
- `RunnerKind.prostration` 的原始值 `"bowing"` 用于兼容 1.5 版本保存的数据，
  不要直接改名。
- `RunnerConfiguration` 会通过 `Codable` 持久化。新增或修改字段时要考虑旧数据
  解码和迁移，不能让升级静默清空用户队伍。
- 像素帧必须非空且位于声明的宽高范围内。渲染结果应继续使用 template image，
  保持无抗锯齿和最近邻式的清晰像素边缘。
- 应用内现有界面文案使用简体中文。新增菜单项、提示和错误信息时保持一致。
- 除非任务明确要求，不要增加分析、监控、联网行为或外部运行时资源。

## 代码与测试

- 遵循现有 Swift 风格：4 空格缩进、清晰的早返回、短小的职责边界，并使用
  Swift API Design Guidelines 命名。
- 可放入 `RunnerCore` 的逻辑不要耦合到 AppKit 控制器，以便直接单元测试。
- 修改动画帧、渲染、时间线、角色类型或持久化模型时，必须补充或更新
  `RunnerCoreTests`。
- 使用 AppKit 或 `NSImage` 的测试需要标注 `@MainActor`。
- 完成代码修改后至少运行 `swift test`；修改打包脚本时还要实际构建对应架构，
  并使用 `lipo` 或现有脚本的架构检查确认产物。

## 打包与发布

- 本地脚本支持 `x86_64`、`arm64` 和 `universal`；GitHub Actions 发布物只包含
  Intel (`x86_64`) 与 Apple Silicon (`arm64`) 两份 DMG。
- 修改版本时同步更新 `Packaging/Info.plist` 中的
  `CFBundleShortVersionString` 和必要时的 `CFBundleVersion`。
- Release 标签格式为 `v<CFBundleShortVersionString>`，例如版本 `1.5.0` 对应
  `v1.5.0`。标签不一致时工作流会失败。
- 手动运行 workflow 只生成 Artifacts；推送 `v*` 标签才创建或更新 GitHub
  Release。
- 当前打包使用 ad-hoc 签名，没有 Developer ID 签名或 notarization。除非相关
  凭据和流程已经实际配置，不要在文档或发布说明中声称安装包已正式签名公证。

## 提交前检查

1. 运行 `git diff --check`，确认没有空白或补丁格式问题。
2. 运行与改动范围相称的测试和构建命令。
3. 检查 `git status --short`，确保没有提交 `.build/`、`dist/` 或无关文件。
4. 行为、命令或发布流程变化时，同步更新 `README.md`。
