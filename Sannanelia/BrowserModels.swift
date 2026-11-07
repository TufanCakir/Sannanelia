import Foundation
import SwiftData

@Model
final class DownloadRecord {
    @Attribute(.unique) var id: UUID
    var filename: String
    var relativePath: String
    var createdAt: Date
    var status: String

    init(id: UUID, filename: String, relativePath: String, status: String) {
        self.id = id
        self.filename = filename
        self.relativePath = relativePath
        self.status = status
        createdAt = .now
    }
}

@Model
final class BrowserBookmark {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String
    var createdAt: Date
    var favicon: Data?
    var sortOrder: Int

    init(title: String, url: String, sortOrder: Int) {
        id = UUID()
        self.title = title
        self.url = url
        createdAt = .now
        self.sortOrder = sortOrder
    }
}

@Model
final class BrowserHistoryEntry {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var visitedAt: Date
    var visitCount: Int

    init(url: String, title: String) {
        id = UUID()
        self.url = url
        self.title = title
        visitedAt = .now
        visitCount = 1
    }
}

@Model
final class PersistedBrowserTab {
    @Attribute(.unique) var id: UUID
    var workspaceID: String
    var title: String
    var url: String?
    var isHome: Bool
    var sortOrder: Int
    var isSelected: Bool

    init(id: UUID, workspaceID: String, title: String, url: String?, isHome: Bool,
         sortOrder: Int, isSelected: Bool) {
        self.id = id
        self.workspaceID = workspaceID
        self.title = title
        self.url = url
        self.isHome = isHome
        self.sortOrder = sortOrder
        self.isSelected = isSelected
    }
}
