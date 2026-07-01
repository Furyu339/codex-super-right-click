//
//  SharedStore.swift
//  Flicker
//
//  Shared between the container app and the Finder Sync extension.
//  Reads/writes the configured AppEntry list via a fixed file path.
//

import Foundation
import os

/// 配置读写。App 与扩展共享一个固定路径文件。
/// 路径：~/Library/Application Support/CodexRightClick/app_entries.json
///
/// 关键点：沙盒扩展里 `urls(for: .applicationSupportDirectory)` 与
/// `homeDirectoryForCurrentUser` 都返回沙盒容器路径而非真实主目录。
/// 因此用 `getpwuid(getuid())` 取真实主目录，保证 App 与扩展读写同一文件。
enum SharedStore {
    static let configFileName = "app_entries.json"
    static let menuSettingsFileName = "menu_settings.json"
    static let newFileSettingsFileName = "new_file_settings.json"
    static let appSupportSubdir = "CodexRightClick"
    private static let logger = Logger(subsystem: "local.codex.rightclick", category: "SharedStore")
    private static let cacheValidationInterval: TimeInterval = 2

    private struct CachedValue<Value> {
        var value: Value
        var modifiedAt: Date?
        var checkedAt: Date
    }

    private static var entriesCache: CachedValue<[AppEntry]>?
    private static var menuSettingsCache: CachedValue<MenuSettings>?
    private static var newFileSettingsCache: CachedValue<NewFileSettings>?

    /// 真实用户主目录（不受沙盒容器重定向影响）。
    private static var realHomeDirectory: URL? {
        guard let pw = getpwuid(getuid()) else { return nil }
        return URL(fileURLWithFileSystemRepresentation: pw.pointee.pw_dir, isDirectory: true, relativeTo: nil)
    }

    /// 共享目录 URL（真实路径，非沙盒容器路径）。
    static var sharedDirectoryURL: URL? {
        guard let home = realHomeDirectory else { return nil }
        let fm = FileManager.default
        let dir = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(appSupportSubdir, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 共享配置文件 URL（真实路径，非沙盒容器路径）。
    static var configFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent(configFileName, isDirectory: false)
    }

    /// 菜单设置文件 URL。
    static var menuSettingsFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent(menuSettingsFileName, isDirectory: false)
    }
    
    /// 新建文件设置文件 URL。
    static var newFileSettingsFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent(newFileSettingsFileName, isDirectory: false)
    }

    /// 读取应用列表。
    static func loadEntries() -> [AppEntry] {
        guard let url = configFileURL else { return AppEntry.codexDefaults }
        let now = Date()
        let modifiedAt = modificationDate(of: url)
        if let cache = entriesCache,
           now.timeIntervalSince(cache.checkedAt) < cacheValidationInterval || cache.modifiedAt == modifiedAt {
            entriesCache?.checkedAt = now
            return cache.value
        }
        guard let data = try? Data(contentsOf: url) else {
            entriesCache = CachedValue(value: AppEntry.codexDefaults, modifiedAt: modifiedAt, checkedAt: now)
            return AppEntry.codexDefaults
        }
        do {
            let decoded = try JSONDecoder().decode([AppEntry].self, from: data)
            let entries = decoded.isEmpty ? AppEntry.codexDefaults : migrateDefaultEntryNames(decoded)
            entriesCache = CachedValue(value: entries, modifiedAt: modifiedAt, checkedAt: now)
            return entries
        } catch {
            logger.error("loadEntries decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func migrateDefaultEntryNames(_ entries: [AppEntry]) -> [AppEntry] {
        let currentDefaults = Dictionary(uniqueKeysWithValues: AppEntry.codexDefaults.map { ($0.id, $0) })
        let oldNames: [String: Set<String>] = [
            "cursor": ["Cursor", "Open in Cursor"],
            "github-desktop": ["GitHub Desktop", "Open in GitHub Desktop"],
            "ghostty": ["Ghostty", "Open in Ghostty"]
        ]

        return entries.map { entry in
            guard let current = currentDefaults[entry.id],
                  oldNames[entry.id]?.contains(entry.name) == true else {
                return entry
            }
            var migrated = entry
            migrated.name = current.name
            return migrated
        }
    }

    /// 写入应用列表。
    @discardableResult
    static func saveEntries(_ entries: [AppEntry]) -> Bool {
        guard let url = configFileURL else { return false }
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
            entriesCache = CachedValue(value: entries, modifiedAt: modificationDate(of: url), checkedAt: Date())
            return true
        } catch {
            logger.error("saveEntries failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Menu Settings

    /// 读取菜单设置。文件不存在时返回默认值。
    static func loadMenuSettings() -> MenuSettings {
        guard let url = menuSettingsFileURL else { return .defaults }
        let now = Date()
        let modifiedAt = modificationDate(of: url)
        if let cache = menuSettingsCache,
           now.timeIntervalSince(cache.checkedAt) < cacheValidationInterval || cache.modifiedAt == modifiedAt {
            menuSettingsCache?.checkedAt = now
            return cache.value
        }
        guard let data = try? Data(contentsOf: url) else {
            menuSettingsCache = CachedValue(value: .defaults, modifiedAt: modifiedAt, checkedAt: now)
            return .defaults
        }
        do {
            let settings = try JSONDecoder().decode(MenuSettings.self, from: data)
            menuSettingsCache = CachedValue(value: settings, modifiedAt: modifiedAt, checkedAt: now)
            return settings
        } catch {
            logger.error("loadMenuSettings decode failed: \(error.localizedDescription, privacy: .public)")
            return .defaults
        }
    }

    /// 写入菜单设置。
    @discardableResult
    static func saveMenuSettings(_ settings: MenuSettings) -> Bool {
        guard let url = menuSettingsFileURL else { return false }
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url, options: .atomic)
            menuSettingsCache = CachedValue(value: settings, modifiedAt: modificationDate(of: url), checkedAt: Date())
            return true
        } catch {
            logger.error("saveMenuSettings failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    // MARK: - New File Settings
    
    /// 读取新建文件设置。文件不存在时返回默认值。
    static func loadNewFileSettings() -> NewFileSettings {
        guard let url = newFileSettingsFileURL else { return .defaults }
        let now = Date()
        let modifiedAt = modificationDate(of: url)
        if let cache = newFileSettingsCache,
           now.timeIntervalSince(cache.checkedAt) < cacheValidationInterval || cache.modifiedAt == modifiedAt {
            newFileSettingsCache?.checkedAt = now
            return cache.value
        }
        guard let data = try? Data(contentsOf: url) else {
            newFileSettingsCache = CachedValue(value: .defaults, modifiedAt: modifiedAt, checkedAt: now)
            return .defaults
        }
        do {
            let settings = try JSONDecoder().decode(NewFileSettings.self, from: data)
            newFileSettingsCache = CachedValue(value: settings, modifiedAt: modifiedAt, checkedAt: now)
            return settings
        } catch {
            logger.error("loadNewFileSettings decode failed: \(error.localizedDescription, privacy: .public)")
            return .defaults
        }
    }
    
    /// 写入新建文件设置。
    @discardableResult
    static func saveNewFileSettings(_ settings: NewFileSettings) -> Bool {
        guard let url = newFileSettingsFileURL else { return false }
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url, options: .atomic)
            newFileSettingsCache = CachedValue(value: settings, modifiedAt: modificationDate(of: url), checkedAt: Date())
            return true
        } catch {
            logger.error("saveNewFileSettings failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }
}
