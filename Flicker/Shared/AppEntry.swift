//
//  AppEntry.swift
//  Flicker
//
//  Shared between the container app and the Finder Sync extension.
//

import Foundation

/// 一个可配置的应用程序条目。
struct AppEntry: Codable, Identifiable, Equatable, Hashable {
    /// 稳定唯一 id（UUID 字符串）
    var id: String
    /// 显示名称（默认取 .app 名）
    var name: String
    /// .app 包的绝对路径
    var appPath: String
    /// 适用文件扩展名（小写、无点）。空数组表示适用所有文件。
    var allowedExtensions: [String]
    /// 仅在文件夹右键时显示该应用。
    /// 为 false 时按扩展名匹配文件（空数组适用所有文件），且对文件夹始终显示。
    var foldersOnly: Bool

    init(id: String = UUID().uuidString,
         name: String,
         appPath: String,
         allowedExtensions: [String] = [],
         foldersOnly: Bool = false) {
        self.id = id
        self.name = name
        self.appPath = appPath
        self.allowedExtensions = allowedExtensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        self.foldersOnly = foldersOnly
    }

    // 兼容旧配置：缺少 foldersOnly 字段时默认 false。
    private enum CodingKeys: String, CodingKey {
        case id, name, appPath, allowedExtensions, foldersOnly
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        appPath = try c.decode(String.self, forKey: .appPath)
        allowedExtensions = try c.decodeIfPresent([String].self, forKey: .allowedExtensions) ?? []
        foldersOnly = try c.decodeIfPresent(Bool.self, forKey: .foldersOnly) ?? false
    }

    /// URL 形式
    var url: URL { URL(fileURLWithPath: appPath) }

    /// 判断是否适用于给定 URL：
    /// - 文件夹：始终显示（无论 foldersOnly）。
    /// - 文件：foldersOnly 为 true 时不显示；否则按扩展名匹配，空数组适用全部。
    func matches(url: URL) -> Bool {
        var isDir: ObjCBool = false
        let isFolder = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        if isFolder { return true }
        if foldersOnly { return false }
        if allowedExtensions.isEmpty { return true }
        let ext = url.pathExtension.lowercased()
        return allowedExtensions.contains(ext)
    }
}

extension AppEntry {
    static let codexDefaults: [AppEntry] = [
        AppEntry(
            id: "cursor",
            name: "在 Cursor 中打开",
            appPath: "/Applications/Cursor.app",
            foldersOnly: false
        ),
        AppEntry(
            id: "github-desktop",
            name: "在 GitHub Desktop 中打开",
            appPath: "/Applications/GitHub Desktop.app",
            foldersOnly: false
        ),
        AppEntry(
            id: "ghostty",
            name: "在 Ghostty 中打开",
            appPath: "/Applications/Ghostty.app",
            foldersOnly: true
        )
    ]
}
