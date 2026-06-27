//
//  ServiceProvider.swift
//  Codex RightClick
//
//  macOS Services fallback for Finder context menus.
//

import AppKit
import Foundation

@MainActor
final class ServiceProvider: NSObject {
    static let shared = ServiceProvider()

    private let appPaths: [String: String] = [
        "cursor": "/Applications/Cursor.app",
        "githubDesktop": "/Applications/GitHub Desktop.app",
        "ghostty": "/Applications/Ghostty.app",
        "codex": "/Applications/Codex.app"
    ]

    private override init() {}

    @objc(handleCodexService:userData:error:)
    func handleCodexService(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = selectedURLs(from: pasteboard)
        guard let action = userData, !urls.isEmpty else { return }

        switch action {
        case "copyPath":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
        case "openCursor":
            open(urls, with: appPaths["cursor"])
        case "openGitHubDesktop":
            open(urls, with: appPaths["githubDesktop"])
        case "openGhostty":
            open(urls.map { directoryURL(for: $0) }, with: appPaths["ghostty"])
        case "openCodex":
            open(urls, with: appPaths["codex"])
        case "newTxt":
            createFile(ext: "txt", template: nil, for: urls)
        case "newMarkdown":
            createFile(ext: "md", template: nil, for: urls)
        case "newWord":
            createFile(ext: "docx", template: "Word.docx", for: urls)
        case "newExcel":
            createFile(ext: "xlsx", template: "Excel.xlsx", for: urls)
        case "newPPT":
            createFile(ext: "pptx", template: "PPT.pptx", for: urls)
        case "grantWrite":
            urls.forEach { grantUserWritePermission(at: $0) }
        default:
            break
        }
    }

    private func selectedURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return urls
        }

        let fileNamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let paths = pasteboard.propertyList(forType: fileNamesType) as? [String] {
            return paths.map { URL(fileURLWithPath: $0) }
        }

        return []
    }

    private func open(_ urls: [URL], with appPath: String?) {
        guard let appPath, FileManager.default.fileExists(atPath: appPath) else { return }
        let appURL = URL(fileURLWithPath: appPath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config)
    }

    private func directoryURL(for url: URL) -> URL {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private func createFile(ext: String, template: String?, for urls: [URL]) {
        guard let first = urls.first else { return }
        let directory = directoryURL(for: first)
        let fileURL = uniqueFileURL(directory: directory, ext: ext)

        if let template, let templateURL = templateURL(named: template),
           (try? FileManager.default.copyItem(at: templateURL, to: fileURL)) != nil {
            return
        }

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }

    private func uniqueFileURL(directory: URL, ext: String) -> URL {
        let baseName = "新建文件"
        var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) \(index).\(ext)")
            index += 1
        }
        return candidate
    }

    private func templateURL(named name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home
                .appendingPathComponent("Library/Application Support/CodexRightClick/Templates/CreateNewFile")
                .appendingPathComponent(name),
            home
                .appendingPathComponent("Library/Group Containers/4K6FWZU8C4.group.cn.better365.iRightMouse/Templates/CreateNewFile")
                .appendingPathComponent(name)
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func grantUserWritePermission(at url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let permissions = attrs[.posixPermissions] as? NSNumber else { return }
        _ = chmod(url.path, mode_t(permissions.intValue | 0o200))
    }
}
