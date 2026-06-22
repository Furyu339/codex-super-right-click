//
//  URLOpener.swift
//  Flicker
//
//  Handles custom URL scheme `flicker://` invoked by the Finder extension.
//
//  背景：Finder Sync 扩展运行在沙箱内，直接调用
//  `NSWorkspace.shared.open([target], withApplicationAt:)` 会被系统拦截，
//  报“应用程序 Flicker 没有权限打开 xxx”。因此扩展改为通过 URL scheme
//  把目标文件与应用路径交给非沙箱的容器 App，由容器 App 真正执行打开。
//

import AppKit

enum URLOpener {
    static let scheme = "flicker"

    /// 处理 `flicker://open?target=<路径>&app=<路径>`。
    static func handle(_ url: URL) {
        guard url.scheme?.lowercased() == scheme else { return }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.host?.lowercased() == "open" else { return }

        let targetPath = comps.queryItems?.first(where: { $0.name == "target" })?.value?
            .removingPercentEncoding
        let appPath = comps.queryItems?.first(where: { $0.name == "app" })?.value?
            .removingPercentEncoding
        guard let targetPath, let appPath else { return }

        let targetURL = URL(fileURLWithPath: targetPath)
        let appURL = URL(fileURLWithPath: appPath)

        // 容器 App 非沙盒，可自由用任意应用打开任意文件。
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([targetURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                NSLog("[Flicker] open via container failed: \(error.localizedDescription)")
            }
        }
    }
}
