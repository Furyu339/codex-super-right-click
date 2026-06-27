//
//  GeneralSettingsPanel.swift
//  Flicker
//
//  "通用设置"配置面板，管理界面和启动相关设置。
//

import SwiftUI

struct GeneralSettingsPanel: View {
    @ObservedObject private var settings = AppSettings.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        Form {
            Section("界面") {
                Toggle("在系统菜单栏显示图标", isOn: $settings.showMenuBarIcon)
                    .help("关闭后将从菜单栏移除 Codex RightClick 图标")
                Toggle("在Dock栏显示", isOn: $settings.showInDock)
                    .help("关闭后应用将作为菜单栏/后台应用运行")
            }
            Section("启动") {
                Toggle("开机时自动启动", isOn: $settings.launchAtLogin)
                    .help("登录 macOS 时自动运行 Codex RightClick")
            }
            Section("关于 Codex RightClick") {
                HStack(spacing: 14) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Codex RightClick")
                            .font(.headline)
                        Text("版本 \(appVersion) (\(buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Text("极简 macOS Finder 右键菜单扩展，提升文件操作效率。")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("本地维护版")
                    Text("Based on Flicker, MIT License")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}
