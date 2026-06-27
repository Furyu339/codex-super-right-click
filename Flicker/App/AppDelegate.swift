//
//  AppDelegate.swift
//  Flicker
//
//  管理 URL 启动检测、窗口复用策略，并按用户设置应用
//  程序坞 / 菜单栏 / 开机自启动。
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 是否因处理自定义 URL 而被拉起（扩展触发"打开方式"）。
    /// 仅在主线程读写。
    nonisolated(unsafe) static var launchedByURL = false

    @MainActor
    static func markLaunchedByURL() {
        launchedByURL = true
        NSApp.setActivationPolicy(.accessory)
    }

    @MainActor
    static func hideURLLaunchWindows() {
        NSApp.windows.forEach { $0.orderOut(nil) }
        NSApp.hide(nil)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 通过 URL 启动时，系统会带上 kAEGetURL Apple Event，direct object 即 URL 字符串。
        let event = NSAppleEventManager.shared().currentAppleEvent
        if let event,
           let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
           url.lowercased().hasPrefix("\(URLOpener.scheme)://") {
            Self.markLaunchedByURL()
        }
        if Self.launchedByURL {
            // 扩展拉起时保持静默：不抢焦点、不显窗口。
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.launchedByURL {
            // 静默运行：隐藏窗口，不应用界面设置，仅同步登录项。
            Self.hideURLLaunchWindows()
            DispatchQueue.main.async {
                Self.hideURLLaunchWindows()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Self.hideURLLaunchWindows()
            }
            AppSettings.shared.applyLoginItem()
        } else {
            AppSettings.shared.applyAll()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 用户再次打开已运行的应用（如从 Dock / Finder 点击）：显示主窗口并应用界面设置。
        showMainWindow()
        AppSettings.shared.applyAll()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 有菜单栏图标时保留进程（可随时重新打开窗口）；否则关闭即退出。
        return !AppSettings.shared.showMenuBarIcon
    }

    @MainActor @objc func showMainWindow() {
        Self.launchedByURL = false
        AppActions.shared.openMainWindow?()
        AppSettings.shared.applyAll()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - URL Handling
    
    func application(_ application: NSApplication, open urls: [URL]) {
        Log.debug("application open urls: \(urls)")
        for url in urls {
            if url.scheme?.lowercased() == URLOpener.scheme {
                Self.markLaunchedByURL()
            }
            URLOpener.handle(url)
        }
    }
}
