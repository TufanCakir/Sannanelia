//
//  BrowserDataService.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation
import Observation
import SwiftData
import WebKit

@MainActor @Observable
final class BrowserDataService {
    private(set) var bookmarks: [BrowserBookmark] = []
    private(set) var history: [BrowserHistoryEntry] = []
    var storageError = false
    var isClearing = false
    @ObservationIgnored private var context: ModelContext?

    func configure(_ context: ModelContext) {
        self.context = context
        refresh()
    }

    func refresh() {
        guard let context else { return }
        do {
            bookmarks = try context.fetch(
                FetchDescriptor<BrowserBookmark>(sortBy: [
                    SortDescriptor(\.sortOrder)
                ])
            )
            history = try context.fetch(
                FetchDescriptor<BrowserHistoryEntry>(sortBy: [
                    SortDescriptor(\.visitedAt, order: .reverse)
                ])
            )
        } catch { storageError = true }
    }

    private func save() {
        guard let context else { return }
        do { try context.save() } catch {
            context.rollback()
            storageError = true
        }
        refresh()
    }

    func addBookmark(title: String, url: URL) {
        guard let context, ["https", "http"].contains(url.scheme ?? "") else {
            return
        }
        if let existing = bookmarks.first(where: {
            $0.url == url.absoluteString
        }) {
            existing.title =
                title.isEmpty ? url.host ?? url.absoluteString : title
        } else {
            context.insert(
                BrowserBookmark(
                    title: title.isEmpty
                        ? url.host ?? url.absoluteString : title,
                    url: url.absoluteString,
                    sortOrder: bookmarks.count
                )
            )
        }
        save()
    }

    func editBookmark(_ bookmark: BrowserBookmark, title: String, url: URL) {
        guard
            !bookmarks.contains(where: {
                $0.id != bookmark.id && $0.url == url.absoluteString
            })
        else {
            storageError = true
            return
        }
        bookmark.title = title.isEmpty ? url.host ?? url.absoluteString : title
        bookmark.url = url.absoluteString
        save()
    }

    func deleteBookmark(_ bookmark: BrowserBookmark) {
        context?.delete(bookmark)
        save()
    }

    func moveBookmarks(from offsets: IndexSet, to destination: Int) {
        var ordered = bookmarks
        let moving = offsets.sorted().map { ordered[$0] }
        for index in offsets.sorted(by: >) { ordered.remove(at: index) }
        ordered.insert(
            contentsOf: moving,
            at: destination - offsets.filter { $0 < destination }.count
        )
        for (index, bookmark) in ordered.enumerated() {
            bookmark.sortOrder = index
        }
        save()
    }

    func recordVisit(url: URL, title: String, isPrivate: Bool) {
        // Privacy is enforced here as well as at the caller boundary.
        guard !isPrivate, let context,
            ["http", "https"].contains(url.scheme ?? "")
        else { return }
        if let existing = history.first(where: { $0.url == url.absoluteString })
        {
            existing.visitedAt = .now
            existing.title = title
            existing.visitCount += 1
        } else {
            context.insert(
                BrowserHistoryEntry(url: url.absoluteString, title: title)
            )
        }
        save()
    }

    func deleteHistory(_ entry: BrowserHistoryEntry) {
        context?.delete(entry)
        save()
    }

    func clearHistory() {
        for entry in history { context?.delete(entry) }
        save()
    }

    func clearWebsiteData(_ types: Set<String>) async {
        guard !isClearing else { return }
        isClearing = true
        await WKWebsiteDataStore.default().removeData(
            ofTypes: types,
            modifiedSince: .distantPast
        )
        isClearing = false
    }
}
