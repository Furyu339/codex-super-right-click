//
//  GeneralSettingsPanel.swift
//  Flicker
//
//  "通用设置"配置面板，管理界面和启动相关设置。
//

import SwiftUI

struct GeneralSettingsPanel: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("界面") {
                Toggle("在系统菜单栏显示图标", isOn: $settings.showMenuBarIcon)
                    .help("关闭后将从菜单栏移除 Flicker 图标")
                Toggle("在Dock栏显示", isOn: $settings.showInDock)
                    .help("关闭后应用将作为菜单栏/后台应用运行")
            }
            Section("启动") {
                Toggle("开机时自动启动", isOn: $settings.launchAtLogin)
                    .help("登录 macOS 时自动运行 Flicker")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    GeneralSettingsPanel()
}
