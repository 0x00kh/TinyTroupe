# TinyTroupe

TinyTroupe 是住在 macOS 菜单栏里的一支迷你动画队伍。

它们会在你工作时认真跑动、趴下、停住，再继续忙自己的事情。没有 Dock
图标，不需要联网，也不会收集数据，只占用屏幕顶端一点点位置，提供一点点
不影响正事的热闹。

所有动画代码、像素帧和图像资源都在这个仓库里，不会从远方临时召唤素材。

## 这支队伍会做什么

- **像素猫负责巡视**：6 帧小短腿循环播放，工作看起来一直很忙。
- **日式跪拜角色负责认真行礼**：8 帧完整动作，从端正跪坐一直伏到桌面。
- **一位不够热闹就多来几位**：可以同时添加多个角色，把菜单栏排成自己的
  迷你舞台。
- **走反了就掉头，累了就休息**：每个角色都能独立切换动画、镜像方向、
  暂停或离场，互不干涉。
- **队长很有记性**：角色数量、排列顺序和各自设置都会自动保存，重新启动后
  仍按原来的队形集合。
- **可以每天准时报到**：通过 macOS 登录项开启开机启动，不用手动点名。
- **步伐统一**：固定每 120 毫秒切换一帧，整齐前进，不争先恐后。
- **不挑菜单栏颜色**：浅色和深色模式都能看清，不会换个主题就隐身。
- **安静守规矩**：没有监控、分析或网络请求，也不会偷偷向谁汇报你今天看了
  它们多少次。

第一次启动时，TinyTroupe 会先派出一个土下座角色。打开任意角色的菜单，
可以继续添加土下座角色或像素猫。每个角色都会记住自己的动画、朝向和暂停
状态；下次打开应用时，整支队伍会回到上次的位置。

## 从源码放它出来

环境要求：macOS 13 或更高版本，以及 Xcode 16 或兼容的 Swift 6 工具链。

```sh
swift run TinyTroupe
```

运行后请看菜单栏，不要在 Dock 里寻找它。TinyTroupe 知道自己的位置。

## 打包成 App

可以分别构建 Intel、Apple Silicon 或 Universal 2 版本：

```sh
./scripts/build-app.sh x86_64
./scripts/build-app.sh arm64
./scripts/build-app.sh universal
```

生成的应用位于 `dist/<架构>/TinyTroupe.app`，并使用 ad-hoc 签名，适合本地
运行。省略架构参数时，默认构建同时支持 Intel 和 Apple Silicon 的
Universal 2 版本。

## 制作 DMG 安装包

一次生成 Intel 和 Apple Silicon 两份安装包：

```sh
./scripts/package-dmg.sh
```

也可以传入 `x86_64`、`arm64` 或 `universal`，只制作指定架构的安装包：

```sh
./scripts/package-dmg.sh arm64
```

安装包会写入 `dist/`。打开 DMG 后，把 TinyTroupe 拖进 `Applications`，
迷你队伍就算正式入住。

## 用 GitHub Actions 自动打包

`Build macOS installers` 工作流只构建两种可下载的 DMG：

- `TinyTroupe-macOS-Intel`：适用于 Intel Mac（`x86_64`）。
- `TinyTroupe-macOS-Apple-Silicon`：适用于 M 系列 Mac（`arm64`）。

在仓库的 Actions 页面手动运行工作流，只会构建并上传 Artifacts，不会创建
Release。Artifacts 会保留 30 天，足够把它们领回家。

## 发布 GitHub Release

发布版本时，先确认 `Packaging/Info.plist` 中的
`CFBundleShortVersionString` 已经更新。Git 标签必须在版本号前加 `v`，并与
它完全一致。例如应用版本为 `1.5.0`，标签就必须是 `v1.5.0`：

```sh
git tag v1.5.0
git push origin v1.5.0
```

标签推送后，GitHub Actions 会依次完成这些工作：

1. 检查标签与应用版本是否一致。
2. 分别构建 Intel 和 Apple Silicon 安装包。
3. 验证 DMG，并计算 SHA-256 校验值。
4. 两种架构都成功后，创建同名 GitHub Release。
5. 自动生成 Release Notes，并上传两份 DMG。

如果 Release 已存在，工作流会替换其中同名的 DMG。只要有一种架构构建
失败，Release 就不会发布；队伍要到齐才出发。

> 当前安装包使用 ad-hoc 签名，尚未配置 Apple Developer ID 签名和 Apple
> notarization。用于公开分发时，macOS Gatekeeper 仍可能显示安全提示。

## 测试

运行测试，确认角色没有跑出画框、配置还能正确保存，时间线也依然按照固定
节拍前进：

```sh
swift test
```
