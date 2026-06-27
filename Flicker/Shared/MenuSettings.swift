//
//  MenuSettings.swift
//  Flicker
//
//  Shared between the container app and the Finder Sync extension.
//  Controls which copy-related menu items appear in the Finder context menu.
//

import Foundation

/// 右键菜单显示设置，控制复制类菜单项的显隐。
struct MenuSettings: Codable {
    /// 显示「复制绝对路径」
    var showCopyAbsolutePath: Bool
    /// 显示「复制相对路径」
    var showCopyRelativePath: Bool
    /// 显示「复制文件名」
    var showCopyFileName: Bool

    /// 默认全开。
    static let defaults = MenuSettings(
        showCopyAbsolutePath: true,
        showCopyRelativePath: false,
        showCopyFileName: false
    )

    // 兼容旧配置：缺少字段时用默认值。
    init(
        showCopyAbsolutePath: Bool = true,
        showCopyRelativePath: Bool = true,
        showCopyFileName: Bool = true
    ) {
        self.showCopyAbsolutePath = showCopyAbsolutePath
        self.showCopyRelativePath = showCopyRelativePath
        self.showCopyFileName = showCopyFileName
    }

    private enum CodingKeys: String, CodingKey {
        case showCopyAbsolutePath, showCopyRelativePath, showCopyFileName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showCopyAbsolutePath = try c.decodeIfPresent(Bool.self, forKey: .showCopyAbsolutePath) ?? true
        showCopyRelativePath = try c.decodeIfPresent(Bool.self, forKey: .showCopyRelativePath) ?? true
        showCopyFileName = try c.decodeIfPresent(Bool.self, forKey: .showCopyFileName) ?? true
    }
}

// MARK: - 新建文件类型

/// 新建文件类型配置
struct NewFileType: Codable, Identifiable, Hashable {
    /// 唯一标识
    let id: String
    /// 显示名称
    let name: String
    /// 文件扩展名（不含点）
    let ext: String
    /// SF Symbols 图标名称
    let icon: String
    
    /// 默认支持的文件类型
    static let defaults: [NewFileType] = [
        NewFileType(id: "txt", name: "TXT", ext: "txt", icon: "doc.text"),
        NewFileType(id: "md", name: "Markdown", ext: "md", icon: "doc.richtext"),
        NewFileType(id: "docx", name: "Word", ext: "docx", icon: "doc.text"),
        NewFileType(id: "xlsx", name: "Excel", ext: "xlsx", icon: "tablecells"),
        NewFileType(id: "pptx", name: "PPT", ext: "pptx", icon: "rectangle.on.rectangle")
    ]
}

// MARK: - 新建文件设置

/// 新建文件功能设置
struct NewFileSettings: Codable {
    /// 启用的文件类型ID列表
    var enabledTypes: [String]
    /// 创建后自动打开
    var autoOpen: Bool
    
    /// 默认设置：启用txt和md，自动打开
    static let defaults = NewFileSettings(
        enabledTypes: NewFileType.defaults.map(\.id),
        autoOpen: false
    )
    
    // 兼容旧配置：缺少字段时用默认值。
    init(
        enabledTypes: [String] = NewFileType.defaults.map(\.id),
        autoOpen: Bool = false
    ) {
        let supported = Set(NewFileType.defaults.map(\.id))
        self.enabledTypes = enabledTypes.filter { supported.contains($0) }
        self.autoOpen = autoOpen
    }
    
    private enum CodingKeys: String, CodingKey {
        case enabledTypes, autoOpen
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let supported = Set(NewFileType.defaults.map(\.id))
        let decodedTypes = try c.decodeIfPresent([String].self, forKey: .enabledTypes) ?? NewFileType.defaults.map(\.id)
        enabledTypes = decodedTypes.filter { supported.contains($0) }
        autoOpen = try c.decodeIfPresent(Bool.self, forKey: .autoOpen) ?? false
    }
}
