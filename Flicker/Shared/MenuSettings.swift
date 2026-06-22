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
        showCopyRelativePath: true,
        showCopyFileName: true
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
