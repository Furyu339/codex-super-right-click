# Flicker

<p align="center">
  <img src="screenshots/app-logo.png" alt="Flicker" width="256" />
</p>

<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT" /></a>
</p>

极简的 macOS Finder 右键菜单扩展，让你用预配置的应用程序快速打开文件或文件夹。

## 截图

<p align="center">
  <img src="screenshots/image1.png" alt="配置界面" width="480" />
  <br/>
  <em>应用配置界面 — 为每个 App 设置适用的文件扩展名</em>
</p>

<p align="center">
  <img src="screenshots/image2.png" alt="Finder 右键菜单效果" width="480" />
  <br/>
  <em>Finder 右键菜单效果 — 一键打开、复制路径</em>
</p>

## 功能

- 对文件/文件夹右键，可选择用预配置的应用程序打开
- 复制选中项的绝对路径或相对路径到剪贴板
- 容器 App 内配置可用应用程序列表（含每个应用适用的文件扩展名）
- 支持「仅文件夹」模式，灵活控制菜单项显示范围

## 工程结构

```
Flicker/
├── App/          # 应用入口、配置列表、添加/编辑面板、Store
├── Shared/       # AppEntry（配置模型）、SharedStore（App Group 共享读写）
└── Resources/    # Info.plist、entitlements、Assets

FlickerExtension/   # Finder Sync 扩展（FIFinderSync 子类）
```

## 快速开始

### 系统要求

- macOS 14.0（Sonoma）或更高版本
- Xcode 16+（构建）

### 构建与运行

```bash
# 命令行构建
xcodebuild -project Flicker.xcodeproj -scheme Flicker -configuration Debug build

# 或在 Xcode 中打开 Flicker.xcodeproj，选 Flicker scheme 直接运行
```

### 打包 DMG

```bash
./scripts/build_dmg.sh
# 产物位于 dist/Flicker.dmg
```

### 首次启用扩展

1. 运行容器 App，点击「添加」选择 `.app`、设置名称与适用扩展名
2. 点击底部「启用 Finder 扩展…」，在 **系统设置 → 隐私与安全性 → 扩展 → 访达** 中勾选 Flicker
3. 重启 Finder（`killall Finder`）后右键即可见

## Fork 后需要修改的配置

如果你 Fork 了本项目并打算自己构建使用，请注意以下配置需要修改为你自己的值：

| 配置项 | 当前值 | 文件位置 |
|--------|--------|----------|
| Bundle Identifier（App） | `com.wangyanan.flicker` | `project.pbxproj` |
| Bundle Identifier（Extension） | `com.wangyanan.flicker.extension` | `project.pbxproj` |
| App Group | `group.com.wangyanan.flicker` | `Shared/SharedStore.swift` |
| URL Scheme | `flicker` | `Resources/Info.plist` |

> **提示：** App Group 需要在 Apple Developer 后台注册后才能使用。本地开发可使用 ad-hoc 签名（`CODE_SIGN_IDENTITY = "-"`），无需开发者账号。

## 技术说明

- 相对路径基准为当前 Finder 窗口文件夹（`targetedURL`），无法获取时回退为绝对路径
- 配置通过 App Group 以 JSON 形式在 App 与扩展间共享
- 最低系统版本 macOS 14.0（Sonoma）

## 贡献

欢迎提交 Issue 和 Pull Request！

- 提交 PR 前请确保代码可以正常编译运行
- 新功能请先开 Issue 讨论可行性
- 请保持代码风格与现有代码一致

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
