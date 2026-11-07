//
//  SannaneliaTests.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation
import SwiftData
import Testing
import WebKit

@testable import Sannanelia

@MainActor
@Suite(.serialized)
struct SannaneliaTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: BrowserBookmark.self,
            BrowserHistoryEntry.self,
            PersistedBrowserTab.self,
            DownloadRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test(arguments: BrowserSearchEngine.allCases)
    func searchEncoding(engine: BrowserSearchEngine) throws {
        let query = "sun & sea + café / שלום"
        let url = try #require(
            BrowserSearchService.destination(for: query, engine: engine)
        )
        #expect(url.scheme == "https")
        #expect(url.absoluteString.contains("%2B"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems
        let parameter: String
        switch engine {
        case .startpage: parameter = "query"
        case .yahoo: parameter = "p"
        default: parameter = "q"
        }
        #expect(items?.first(where: { $0.name == parameter })?.value == query)
    }

    @Test(arguments: [
        "javascript:alert(1)", "file:///etc/passwd", "data:text/html,hello",
        "https://", "https://user:password@example.com", "ftp://example.com",
        "",
    ])
    func rejectsUnsafeOrInvalidInput(input: String) {
        #expect(
            BrowserSearchService.destination(for: input, engine: .duckDuckGo)
                == nil
        )
    }

    @Test func prefersHTTPS() {
        #expect(
            BrowserSearchService.destination(
                for: "example.com/path",
                engine: .duckDuckGo
            )?.absoluteString == "https://example.com/path"
        )
        #expect(
            BrowserSearchService.destination(
                for: "http://localhost:8080",
                engine: .duckDuckGo
            )?.scheme == "http"
        )
    }

    @Test func privateTabsNeverPersistAndReleaseTheirSession() throws {
        let storage = try container()
        let data = BrowserDataService()
        data.configure(storage.mainContext)
        let manager = BrowserTabManager()
        _ = manager.configure(
            context: storage.mainContext,
            data: data,
            suggestedWorkspaceID: UUID().uuidString
        )
        defer { manager.detach() }
        let normal = try #require(manager.selectedTab)
        let original = try #require(normal.session)
        let privateTab = manager.add(isPrivate: true)
        let privateSession = try #require(privateTab.session)
        #expect(
            !privateSession.webView.configuration.websiteDataStore.isPersistent
        )
        #expect(original.webView.configuration.websiteDataStore.isPersistent)
        manager.select(normal)
        #expect(normal.session === original)
        manager.persist()
        let saved = try storage.mainContext.fetch(
            FetchDescriptor<PersistedBrowserTab>()
        )
        #expect(!saved.contains(where: { $0.id == privateTab.id }))
        let url = try #require(URL(string: "https://example.com"))
        data.recordVisit(url: url, title: "Private", isPrivate: true)
        #expect(data.history.isEmpty)
        manager.endPrivateSession()
        #expect(privateTab.session == nil)
        #expect(manager.privateTabs.isEmpty)
        #expect(manager.closedTabs.isEmpty)
    }

    @Test func restoresNormalTabsAndClosedTabs() throws {
        let previous = UserDefaults.standard.object(forKey: "restoreTabs")
        UserDefaults.standard.set(true, forKey: "restoreTabs")
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: "restoreTabs")
            } else {
                UserDefaults.standard.removeObject(forKey: "restoreTabs")
            }
        }
        let storage = try container()
        let data = BrowserDataService()
        data.configure(storage.mainContext)
        let manager = BrowserTabManager()
        let owner = manager.configure(
            context: storage.mainContext,
            data: data,
            suggestedWorkspaceID: UUID().uuidString
        )
        let second = manager.add()
        let secondID = second.id
        manager.persist()
        manager.detach()
        let restored = BrowserTabManager()
        _ = restored.configure(
            context: storage.mainContext,
            data: data,
            suggestedWorkspaceID: owner
        )
        defer { restored.detach() }
        #expect(restored.normalTabs.count == 2)
        #expect(restored.selectedID == secondID)
        let closing = try #require(restored.selectedTab)
        restored.close(closing)
        #expect(restored.normalTabs.count == 1)
        restored.restoreClosedTab()
        #expect(restored.normalTabs.count == 2)
        #expect(restored.closedTabs.isEmpty)
        #expect(restored.selectedID != secondID)
    }

    @Test func detachingWindowDiscardsPrivateTabs() throws {
        let storage = try container()
        let data = BrowserDataService()
        data.configure(storage.mainContext)
        let manager = BrowserTabManager()
        let owner = manager.configure(
            context: storage.mainContext,
            data: data,
            suggestedWorkspaceID: UUID().uuidString
        )
        let tab = manager.add(isPrivate: true)
        let session = try #require(tab.session)
        session.consoleStore.append(level: .log, text: "Private page")
        manager.detach()
        #expect(manager.privateTabs.isEmpty)
        #expect(tab.session == nil)
        #expect(session.consoleStore.messages.isEmpty)
        _ = manager.configure(
            context: storage.mainContext,
            data: data,
            suggestedWorkspaceID: owner
        )
        #expect(manager.selectedTab?.isPrivate == false)
        #expect(manager.selectedTab?.session != nil)
        manager.detach()
    }

    @Test func invalidNavigationShowsAnError() {
        let session = BrowserSession()
        defer { session.close() }
        session.navigate("javascript:alert(1)", engine: .google)
        if case .invalidAddress = session.failure {
            #expect(!session.isHome)
        } else {
            Issue.record("Invalid navigation must display an address error.")
        }
    }

    @Test func bookmarksAndHistoryAvoidDuplicatesAndDeleteSeparately() throws {
        let storage = try container()
        let data = BrowserDataService()
        data.configure(storage.mainContext)
        let url = try #require(URL(string: "https://example.com"))
        data.addBookmark(title: "First", url: url)
        data.addBookmark(title: "Updated", url: url)
        #expect(data.bookmarks.count == 1)
        #expect(data.bookmarks.first?.title == "Updated")
        data.recordVisit(url: url, title: "Example", isPrivate: false)
        data.recordVisit(url: url, title: "Example", isPrivate: false)
        #expect(data.history.count == 1)
        #expect(data.history.first?.visitCount == 2)
        data.clearHistory()
        #expect(data.history.isEmpty)
        #expect(data.bookmarks.count == 1)
    }
}
