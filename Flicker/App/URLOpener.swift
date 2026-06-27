//
//  URLOpener.swift
//  Flicker
//
//  Handles custom URL scheme `codexrightclick://` invoked by the Finder extension.
//
//  背景：Finder Sync 扩展运行在沙箱内，直接调用
//  `NSWorkspace.shared.open([target], withApplicationAt:)` 会被系统拦截，
//  报“应用程序 Flicker 没有权限打开 xxx”。因此扩展改为通过 URL scheme
//  把目标文件与应用路径交给非沙箱的容器 App，由容器 App 真正执行打开。
//

import AppKit

enum URLOpener {
    static let scheme = "codexrightclick"

    /// 处理 `codexrightclick://open`、`codexrightclick://newfile`、`codexrightclick://extract` 和 `codexrightclick://grantwrite`。
    static func handle(_ url: URL) {
        Log.debug("URLOpener.handle called with url: \(url)")
        guard url.scheme?.lowercased() == scheme else {
            Log.debug("invalid scheme: \(url.scheme ?? "nil")")
            return
        }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Log.error("failed to parse URLComponents")
            return
        }
        
        Log.debug("host=\(comps.host ?? "nil")")
        
        switch comps.host?.lowercased() {
        case "open":
            handleOpen(comps)
        case "newfile":
            handleNewFile(comps)
        case "extract":
            handleExtract(comps)
        case "grantwrite":
            handleGrantWrite(comps)
        default:
            Log.debug("unknown host: \(comps.host ?? "nil")")
            return
        }
    }
    
    /// 处理 `codexrightclick://open?target=<路径>&app=<路径>`。
    private static func handleOpen(_ comps: URLComponents) {
        let targetPath = comps.queryItems?.first(where: { $0.name == "target" })?.value?
            .removingPercentEncoding
        let appPath = comps.queryItems?.first(where: { $0.name == "app" })?.value?
            .removingPercentEncoding
        guard let targetPath, let appPath else { return }

        let targetURL = URL(fileURLWithPath: targetPath)
        let appURL = URL(fileURLWithPath: appPath)

        // 容器 App 非沙盒，可自由用任意应用打开任意文件。
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false   // 不要激活目标应用的窗口
        NSWorkspace.shared.open([targetURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                Log.error("open via container failed: \(error.localizedDescription)")
            }
        }

        hideApp()
    }
    
    /// 处理 `codexrightclick://newfile?type=<类型>&path=<目录路径>`。
    private static func handleNewFile(_ comps: URLComponents) {
        Log.debug("handleNewFile called")
        
        let type = comps.queryItems?.first(where: { $0.name == "type" })?.value
        let path = comps.queryItems?.first(where: { $0.name == "path" })?.value?.removingPercentEncoding
        
        Log.debug("type=\(type ?? "nil"), path=\(path ?? "nil")")
        
        guard let type, let path else {
            Log.error("missing type or path")
            return
        }
        
        // 查找文件类型
        guard let fileType = NewFileType.defaults.first(where: { $0.id == type }) else {
            Log.error("unknown file type: \(type)")
            return
        }
        
        Log.debug("fileType=\(fileType.name), ext=\(fileType.ext)")
        
        // 创建文件
        let fileURL = createNewFile(fileType: fileType, directory: path)
        
        // 根据设置决定是否自动打开
        let settings = SharedStore.loadNewFileSettings()
        Log.debug("autoOpen=\(settings.autoOpen), fileURL=\(fileURL?.path ?? "nil")")
        
        if settings.autoOpen, let fileURL {
            Log.debug("opening file: \(fileURL.path)")
            NSWorkspace.shared.open(fileURL)
        }
        
        hideApp()
    }

    
    /// 创建新文件，处理重名冲突。
    private static func createNewFile(fileType: NewFileType, directory: String) -> URL? {
        Log.debug("createNewFile: directory=\(directory), ext=\(fileType.ext)")
        
        let baseURL = URL(fileURLWithPath: directory)
        let baseName = windowsStyleBaseName(for: fileType)
        var fileName = "\(baseName).\(fileType.ext)"
        var fileURL = baseURL.appendingPathComponent(fileName)
        
        Log.debug("initial fileURL=\(fileURL.path)")
        
        // 检查目录是否存在
        var isDir: ObjCBool = false
        let dirExists = FileManager.default.fileExists(atPath: directory, isDirectory: &isDir)
        Log.debug("directory exists=\(dirExists), isDir=\(isDir.boolValue)")
        
        if !dirExists {
            Log.error("directory does not exist!")
            return nil
        }
        
        // 处理重名：添加数字后缀
        var counter = 2
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileName = "\(baseName) (\(counter)).\(fileType.ext)"
            fileURL = baseURL.appendingPathComponent(fileName)
            counter += 1
        }
        
        Log.debug("final fileURL=\(fileURL.path)")
        
        if let templateURL = templateURL(for: fileType) {
            do {
                try FileManager.default.copyItem(at: templateURL, to: fileURL)
                Log.debug("SUCCESS copied template: \(templateURL.path) -> \(fileURL.path)")
                return fileURL
            } catch {
                Log.error("FAILED to copy template: \(error.localizedDescription)")
            }
        }

        let success = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        if success { return fileURL }

        Log.error("FAILED to create file: \(fileURL.path)")
        let dirWritable = FileManager.default.isWritableFile(atPath: directory)
        Log.error("directory writable=\(dirWritable)")
        return nil
    }

    private static func windowsStyleBaseName(for fileType: NewFileType) -> String {
        switch fileType.ext {
        case "txt": return "新建 文本文档"
        case "md": return "新建 Markdown 文件"
        case "docx": return "新建 Microsoft Word 文档"
        case "xlsx": return "新建 Microsoft Excel 工作表"
        case "pptx": return "新建 Microsoft PowerPoint 演示文稿"
        default: return "新建文件"
        }
    }

    /// 处理 `codexrightclick://extract?archive=<压缩包路径>`。
    private static func handleExtract(_ comps: URLComponents) {
        let archives = comps.queryItems?
            .filter { $0.name == "archive" }
            .compactMap(\.value)
            .map { URL(fileURLWithPath: $0) } ?? []

        guard !archives.isEmpty else {
            Log.error("extract: missing archive")
            return
        }

        for archive in archives {
            extractArchive(archive)
        }
        hideApp()
    }

    private static func extractArchive(_ archive: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard FileManager.default.fileExists(atPath: archive.path) else {
                Log.error("extract: archive does not exist: \(archive.path)")
                return
            }
            guard let sevenZipURL = sevenZipExecutableURL() else {
                Log.error("extract: missing 7zz executable")
                return
            }

            let destination = uniqueExtractionDirectory(for: archive)
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            } catch {
                Log.error("extract: create folder failed: \(error.localizedDescription)")
                return
            }

            let exitCode = runSevenZip(sevenZipURL, archive: archive, destination: destination)
            guard exitCode == 0 else {
                Log.error("extract failed: exit=\(exitCode), archive=\(archive.path)")
                return
            }

            expandSingleTarIfNeeded(in: destination, using: sevenZipURL)
            Log.debug("extract finished: \(archive.path) -> \(destination.path)")
        }
    }

    @discardableResult
    private static func runSevenZip(_ sevenZipURL: URL, archive: URL, destination: URL) -> Int32 {
        let process = Process()
        process.executableURL = sevenZipURL
        process.currentDirectoryURL = destination
        process.arguments = [
            "x",
            "-y",
            "-aou",
            "-o\(destination.path)",
            archive.path
        ]
        process.environment = [
            "LANG": "zh_CN.UTF-8",
            "LC_ALL": "zh_CN.UTF-8"
        ]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            Log.error("extract launch failed: \(error.localizedDescription)")
            return -1
        }
    }

    private static func expandSingleTarIfNeeded(in destination: URL, using sevenZipURL: URL) {
        do {
            let children = try FileManager.default.contentsOfDirectory(
                at: destination,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            let tarFiles = children.filter { url in
                url.pathExtension.lowercased() == "tar"
                    && ((try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false)
            }
            guard children.count == 1, let tarURL = tarFiles.first else { return }

            let exitCode = runSevenZip(sevenZipURL, archive: tarURL, destination: destination)
            if exitCode == 0 {
                try? FileManager.default.removeItem(at: tarURL)
            } else {
                Log.error("extract inner tar failed: exit=\(exitCode), tar=\(tarURL.path)")
            }
        } catch {
            Log.error("extract inner tar check failed: \(error.localizedDescription)")
        }
    }

    private static func uniqueExtractionDirectory(for archive: URL) -> URL {
        let parent = archive.deletingLastPathComponent()
        let baseName = archiveBaseName(archive)
        var candidate = parent.appendingPathComponent(baseName, isDirectory: true)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(baseName) (\(counter))", isDirectory: true)
            counter += 1
        }
        return candidate
    }

    private static func archiveBaseName(_ archive: URL) -> String {
        let fileName = archive.lastPathComponent
        let lower = fileName.lowercased()
        for suffix in [".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lzma", ".tbz2", ".tbz", ".tgz", ".txz", ".tzst"] {
            if lower.hasSuffix(suffix) {
                return String(fileName.dropLast(suffix.count))
            }
        }
        return archive.deletingPathExtension().lastPathComponent
    }

    /// 处理 `codexrightclick://grantwrite?target=<路径>`。
    private static func handleGrantWrite(_ comps: URLComponents) {
        let targets = comps.queryItems?
            .filter { $0.name == "target" }
            .compactMap(\.value)
            .map { URL(fileURLWithPath: $0) } ?? []

        guard !targets.isEmpty else {
            Log.error("grantwrite: missing target")
            return
        }

        for target in targets {
            grantUserWritePermission(at: target)
        }
        hideApp()
    }

    private static func grantUserWritePermission(at url: URL) {
        let path = url.path
        let fm = FileManager.default
        do {
            let attrs = try fm.attributesOfItem(atPath: path)
            guard let permissions = attrs[.posixPermissions] as? NSNumber else {
                Log.error("grantwrite: missing posix permissions: \(path)")
                return
            }

            let current = permissions.intValue
            let updated = current | 0o200
            guard chmod(path, mode_t(updated)) == 0 else {
                Log.error("grantwrite: chmod failed errno=\(errno), path=\(path)")
                return
            }
            Log.debug("grantwrite: chmod \(String(current, radix: 8)) -> \(String(updated, radix: 8)), path=\(path)")
        } catch {
            Log.error("grantwrite: read attributes failed: \(error.localizedDescription), path=\(path)")
        }
    }

    private static func sevenZipExecutableURL() -> URL? {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("7zz")
        if let bundled, FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        let homebrew = URL(fileURLWithPath: "/opt/homebrew/bin/7zz")
        if FileManager.default.isExecutableFile(atPath: homebrew.path) {
            return homebrew
        }
        return nil
    }

    private static func templateURL(for fileType: NewFileType) -> URL? {
        let templateName: String
        switch fileType.ext {
        case "docx": templateName = "Word.docx"
        case "xlsx": templateName = "Excel.xlsx"
        case "pptx": templateName = "PPT.pptx"
        default: return nil
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home
                .appendingPathComponent("Library/Application Support/CodexRightClick/Templates/CreateNewFile")
                .appendingPathComponent(templateName),
            home
                .appendingPathComponent("Library/Group Containers/4K6FWZU8C4.group.cn.better365.iRightMouse/Templates/CreateNewFile")
                .appendingPathComponent(templateName)
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
    
    /// 隐藏应用，避免主窗口抢占焦点。
    private static func hideApp() {
        if AppDelegate.launchedByURL {
            // 冷启动场景：保持 accessory 策略，隐藏残留窗口。
            NSApp.windows.forEach { $0.orderOut(nil) }
        } else {
            // 已在运行的场景：隐藏整个应用，让用户继续留在 Finder。
            NSApp.hide(nil)
        }
    }
}
