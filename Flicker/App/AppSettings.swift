//
//  AppSettings.swift
//  Flicker
//
//  用户偏好：菜单栏图标、程序坞、开机自启动。持久化于 UserDefaults；
//  开机自启动用 SMAppService（macOS 13+）。
//

import AppKit
import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let menuBar = "showMenuBarIcon"
        static let dock = "showInDock"
        static let login = "launchAtLogin"
    }

    private func persistMenuSettings() {
        SharedStore.saveMenuSettings(MenuSettings(
            showCopyAbsolutePath: showCopyAbsolutePath,
            showCopyRelativePath: showCopyRelativePath,
            showCopyFileName: showCopyFileName
        ))
    }

    private let defaults = UserDefaults.standard

    /// 在系统菜单栏显示应用图标。
    @Published var showMenuBarIcon: Bool = true {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Key.menuBar)
            applyMenuBar()
        }
    }
    /// 在程序坞中显示应用。
    @Published var showInDock: Bool = true {
        didSet {
            defaults.set(showInDock, forKey: Key.dock)
            applyDock()
        }
    }
    /// 开机时自动启动。
    @Published var launchAtLogin: Bool = false {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.login)
            applyLoginItem()
        }
    }

    // MARK: - 右键菜单开关（通过 SharedStore 与扩展共享）

    /// 显示「复制绝对路径」。
    @Published var showCopyAbsolutePath: Bool = true {
        didSet { persistMenuSettings() }
    }
    /// 显示「复制相对路径」。
    @Published var showCopyRelativePath: Bool = true {
        didSet { persistMenuSettings() }
    }
    /// 显示「复制文件名」。
    @Published var showCopyFileName: Bool = true {
        didSet { persistMenuSettings() }
    }

    init() {
        showMenuBarIcon = (defaults.object(forKey: Key.menuBar) as? Bool) ?? true
        showInDock = (defaults.object(forKey: Key.dock) as? Bool) ?? true
        launchAtLogin = (defaults.object(forKey: Key.login) as? Bool) ?? false

        let menuSettings = SharedStore.loadMenuSettings()
        showCopyAbsolutePath = menuSettings.showCopyAbsolutePath
        showCopyRelativePath = menuSettings.showCopyRelativePath
        showCopyFileName = menuSettings.showCopyFileName
    }

    /// 应用全部设置（正常启动或用户重新打开应用时调用）。
    func applyAll() {
        applyDock()
        applyMenuBar()
        applyLoginItem()
    }

    func applyDock() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    func applyMenuBar() {
        AppMenuBar.shared.setVisible(showMenuBarIcon)
    }

    func applyLoginItem() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("[Flicker] login item toggle failed: \(error.localizedDescription)")
        }
    }
}
