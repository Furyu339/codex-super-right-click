//
//  FinderSync.swift
//  FlickerExtension
//
//  Finder Sync extension principal class.
//

import Cocoa
import Darwin
import FinderSync

final class FinderSync: FIFinderSync {
    private let urlScheme = "codexrightclick"
    private static let archiveExtensions: Set<String> = [
        "7z", "zip", "zipx", "rar", "r00", "001",
        "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "zst", "tzst",
        "lzma", "cab", "arj", "lzh", "lha", "iso", "dmg", "xar", "pkg", "jar"
    ]

    override init() {
        super.init()
        let watchedDirectories = Self.defaultWatchedDirectories()
        FIFinderSyncController.default().directoryURLs = watchedDirectories
        Self.debugLog("init watched=\(watchedDirectories.map(\.path).sorted().joined(separator: ","))")
    }

    private static func defaultWatchedDirectories() -> Set<URL> {
        let fm = FileManager.default
        var urls: Set<URL> = [
            URL(fileURLWithPath: "/Volumes", isDirectory: true)
        ]
        if let homeDirectory = realHomeDirectory() {
            urls.insert(homeDirectory)
        }
        return urls.filter { fm.fileExists(atPath: $0.path) }
    }

    private static func realHomeDirectory() -> URL? {
        guard let pw = getpwuid(getuid()) else { return nil }
        return URL(fileURLWithFileSystemRepresentation: pw.pointee.pw_dir, isDirectory: true, relativeTo: nil)
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "Codex RightClick")
        Self.debugLog("menu kind=\(menuKind.rawValue) target=\(FIFinderSyncController.default().targetedURL()?.path ?? "nil") selected=\(FIFinderSyncController.default().selectedItemURLs()?.map(\.path).joined(separator: ",") ?? "nil")")
        
        // 处理空白区域右键（容器菜单）
        if menuKind == .contextualMenuForContainer {
            // 获取当前目录
            if let targetURL = FIFinderSyncController.default().targetedURL() {
                let menuSettings = SharedStore.loadMenuSettings()
                if menuSettings.showCopyAbsolutePath {
                    addCopyPathMenuItem(to: menu, path: targetURL.path)
                }
                addNewFileMenu(to: menu, directory: targetURL.path)
            }
            return menu
        }

        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForSidebar,
              let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else {
            return menu
        }
        let target = urls[0]

        if urls.contains(where: Self.isArchiveURL) {
            let item = NSMenuItem(title: "解压到单独文件夹", action: #selector(extractToSeparateFolder(_:)), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        // Open in App 子菜单
        let entries = SharedStore.loadEntries()
        let matched = entries.filter { $0.matches(url: target) }
        if !matched.isEmpty {
            let openItem = NSMenuItem(title: "在应用中打开", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "Open in App")
            for entry in matched {
                let item = NSMenuItem(title: entry.name, action: #selector(openWithApp(_:)), keyEquivalent: "")
                item.target = self
                item.tag = entry.id.hashValue
                item.image = NSWorkspace.shared.icon(forFile: entry.appPath)
                item.image?.size = NSSize(width: 16, height: 16)
                submenu.addItem(item)
            }
            openItem.submenu = submenu
            menu.addItem(openItem)
        }

        // 复制类菜单项（受菜单设置控制）
        let menuSettings = SharedStore.loadMenuSettings()
        if menuSettings.showCopyAbsolutePath {
            menu.addItem(withTitle: "复制路径", action: #selector(copyAbsolutePath(_:)), keyEquivalent: "")
        }
        if menuSettings.showCopyRelativePath {
            menu.addItem(withTitle: "复制相对路径", action: #selector(copyRelativePath(_:)), keyEquivalent: "")
        }
        if menuSettings.showCopyFileName {
            menu.addItem(withTitle: "复制文件名", action: #selector(copyFileName(_:)), keyEquivalent: "")
        }
        
        // 新建文件子菜单（仅在文件夹或文件所在目录显示）
        let directory = getTargetDirectory(for: target)
        if let directory {
            addNewFileMenu(to: menu, directory: directory)
        }

        menu.addItem(withTitle: "授权写入", action: #selector(grantWritePermission(_:)), keyEquivalent: "")

        Self.debugLog("return menu items=\(menu.items.map(\.title).joined(separator: ","))")
        return menu
    }

    private static func debugLog(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = base.appendingPathComponent("codex-rightclick-findersync.log")
        guard let data = line.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    private static func isArchiveURL(_ url: URL) -> Bool {
        archiveExtensions.contains(url.pathExtension.lowercased())
    }

    private func addCopyPathMenuItem(to menu: NSMenu, path: String) {
        let item = NSMenuItem(title: "复制路径", action: #selector(copyAbsolutePath(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = path
        menu.addItem(item)
    }
    
    /// 添加新建文件子菜单到指定菜单。
    private func addNewFileMenu(to menu: NSMenu, directory: String) {
        let newFileSettings = SharedStore.loadNewFileSettings()
        let enabledTypes = NewFileType.defaults.filter { newFileSettings.enabledTypes.contains($0.id) }
        guard !enabledTypes.isEmpty else { return }
        
        let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let newFileSubmenu = NSMenu(title: "New File")
        for fileType in enabledTypes {
            let item = NSMenuItem(
                title: "\(fileType.name) (.\(fileType.ext))",
                action: #selector(createNewFile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.toolTip = "\(fileType.id)|\(directory)"
            if let icon = Self.newFileMenuIcon(for: fileType) {
                item.image = icon
            }
            newFileSubmenu.addItem(item)
        }
        newFileItem.submenu = newFileSubmenu
        menu.addItem(newFileItem)
    }

    private static func newFileMenuIcon(for fileType: NewFileType) -> NSImage? {
        if let appIconName = appIconName(for: fileType.ext),
           let resourceURL = Bundle.main.url(forResource: appIconName, withExtension: "icns"),
           let icon = NSImage(contentsOf: resourceURL) {
            icon.size = NSSize(width: 16, height: 16)
            return icon
        }

        let icon = NSImage(systemSymbolName: fileType.icon, accessibilityDescription: nil)
        icon?.size = NSSize(width: 16, height: 16)
        return icon
    }

    private static func appIconName(for fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "txt": return "TextEdit"
        case "md": return "Markdown"
        case "docx": return "OfficeWord"
        case "xlsx": return "OfficeExcel"
        case "pptx": return "OfficePowerPoint"
        default: return nil
        }
    }
    
    /// 获取目标目录路径（如果是文件夹则返回其路径，否则返回文件所在目录）。
    private func getTargetDirectory(for url: URL) -> String? {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
            return url.path
        }
        return url.deletingLastPathComponent().path
    }

    // MARK: - Actions

    @objc private func openWithApp(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let entries = SharedStore.loadEntries()
        // tag 不可靠地反查 id（hashValue 可能冲突），改用 title 匹配名称。
        guard let entry = entries.first(where: { $0.name == sender.title || $0.id.hashValue == sender.tag }) else { return }

        // 扩展处于沙盒，直接用 NSWorkspace 打开会被系统拦截。
        // 改为通过自定义 URL scheme 拉起非沙盒的容器 App，由其执行打开动作。
        // 多选时逐个发送 URL scheme，由容器 App 依次打开。
        for target in urls {
            guard var comps = URLComponents(string: "\(urlScheme)://open") else { continue }
            comps.queryItems = [
                URLQueryItem(name: "target", value: target.path),
                URLQueryItem(name: "app", value: entry.appPath)
            ]
            guard let url = comps.url else { continue }
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func extractToSeparateFolder(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let archives = urls.filter(Self.isArchiveURL)
        guard !archives.isEmpty, var comps = URLComponents(string: "\(urlScheme)://extract") else { return }
        comps.queryItems = archives.map { URLQueryItem(name: "archive", value: $0.path) }
        guard let url = comps.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func copyAbsolutePath(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String, !path.isEmpty {
            copyToPasteboard(path)
            return
        }

        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let paths = urls.map(\.path).joined(separator: "\n")
        copyToPasteboard(paths)
    }

    @objc private func copyRelativePath(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let base = FIFinderSyncController.default().targetedURL()
        let paths = urls.map { url -> String in
            if let base { return relativePath(of: url, to: base) } else { return url.path }
        }.joined(separator: "\n")
        copyToPasteboard(paths)
    }

    @objc private func copyFileName(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        let names = urls.map(\.lastPathComponent).joined(separator: "\n")
        copyToPasteboard(names)
    }
    
    @objc private func createNewFile(_ sender: NSMenuItem) {
        Log.debug("createNewFile called")
        Log.debug("title=\(sender.title)")
        Log.debug("toolTip=\(sender.toolTip ?? "nil")")
        Log.debug("tag=\(sender.tag)")
        
        guard let identifier = sender.toolTip,
              let separatorIndex = identifier.firstIndex(of: "|") else {
            Log.debug("missing or invalid toolTip, trying to parse from title")
            // 尝试从 title 中解析文件类型
            let title = sender.title
            if let ext = extractExtension(from: title) {
                Log.debug("extracted ext=\(ext) from title")
                // 使用 targetedURL 获取当前目录
                if let targetURL = FIFinderSyncController.default().targetedURL() {
                    let path = targetURL.path
                    Log.debug("using targetedURL path=\(path)")
                    proceedWithNewFile(type: ext, path: path)
                    return
                }
            }
            Log.error("could not determine file type")
            return
        }
        
        let type = String(identifier[identifier.startIndex..<separatorIndex])
        let path = String(identifier[identifier.index(after: separatorIndex)...])
        
        Log.debug("type=\(type), path=\(path)")
        proceedWithNewFile(type: type, path: path)
    }
    
    /// 从标题中提取文件扩展名，如 "文本文档 (.txt)" -> "txt"
    private func extractExtension(from title: String) -> String? {
        // 查找括号中的扩展名
        guard let start = title.lastIndex(of: "("),
              let end = title.lastIndex(of: ")"),
              start < end else { return nil }
        let extRange = title.index(after: start)..<end
        var ext = String(title[extRange])
        // 移除开头的点
        if ext.hasPrefix(".") {
            ext = String(ext.dropFirst())
        }
        return ext.isEmpty ? nil : ext
    }
    
    /// 通过 URL Scheme 调用容器 App 创建文件
    private func proceedWithNewFile(type: String, path: String) {
        Log.debug("proceedWithNewFile: type=\(type), path=\(path)")
        guard var comps = URLComponents(string: "\(urlScheme)://newfile") else {
            Log.error("proceedWithNewFile: failed to create URLComponents")
            return
        }
        comps.queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "path", value: path)
        ]
        guard let url = comps.url else {
            Log.error("proceedWithNewFile: failed to create URL")
            return
        }
        Log.debug("proceedWithNewFile: opening URL: \(url)")
        NSWorkspace.shared.open(url)
    }

    @objc private func grantWritePermission(_ sender: NSMenuItem) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        for target in urls {
            grantUserWritePermission(at: target)
        }
    }

    private func grantUserWritePermission(at url: URL) {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let permissions = attrs[.posixPermissions] as? NSNumber else { return }
        let current = permissions.intValue
        let updated = current | 0o200
        _ = chmod(url.path, mode_t(updated))
    }

    // MARK: - Helpers

    /// 计算 target 相对于 base 的路径（如 "sub/file.txt"、"../sibling/file.txt"）。
    /// base 不在 target 的祖先链上时回退为 target 的绝对路径。
    private func relativePath(of target: URL, to base: URL) -> String {
        let baseComps = base.standardizedFileURL.pathComponents
        let targetComps = target.standardizedFileURL.pathComponents
        // 找公共前缀
        var i = 0
        while i < baseComps.count - 1, i < targetComps.count - 1, baseComps[i] == targetComps[i] {
            i += 1
        }
        // base 剩余的每一级都对应一次 ".."
        let ups = max(0, baseComps.count - 1 - i)
        let downs = Array(targetComps.dropFirst(i))
        var parts: [String] = Array(repeating: "..", count: ups)
        parts.append(contentsOf: downs)
        return parts.isEmpty ? "." : parts.joined(separator: "/")
    }

    private func copyToPasteboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}
