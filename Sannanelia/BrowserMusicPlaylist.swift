//
//  BrowserMusicPlaylist.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 08.11.26.
//

import Foundation
import SwiftData

@Model
final class BrowserMusicPlaylist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var trackIDs: [UUID]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.trackIDs = []
    }

    func contains(_ id: UUID) -> Bool {
        trackIDs.contains(id)
    }

    func add(_ id: UUID) {
        guard !contains(id) else { return }
        trackIDs.append(id)
    }

    func remove(_ id: UUID) {
        trackIDs.removeAll { $0 == id }
    }
}
