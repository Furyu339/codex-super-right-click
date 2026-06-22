//
//  FlickerApp.swift
//  Flicker
//
//  Container app entry point.
//

import SwiftUI

@main
struct FlickerApp: App {
    @StateObject private var store = AppEntryStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 560, minHeight: 420)
                .onOpenURL { url in
                    URLOpener.handle(url)
                }
        }
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}
