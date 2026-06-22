//
//  AppEntryStore.swift
//  Flicker
//
//  Observable store backing the configuration UI; persists via SharedStore.
//

import Foundation
import SwiftUI

@MainActor
final class AppEntryStore: ObservableObject {
    @Published private(set) var entries: [AppEntry] = []

    init() {
        reload()
    }

    func reload() {
        entries = SharedStore.loadEntries()
    }

    func add(_ entry: AppEntry) {
        entries.append(entry)
        persist()
    }

    func update(_ entry: AppEntry) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[i] = entry
        persist()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ entry: AppEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        SharedStore.saveEntries(entries)
    }
}
