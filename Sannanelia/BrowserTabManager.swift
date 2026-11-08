//
//  BrowserTabManager.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation
import Observation
import SwiftData
import WebKit

@MainActor @Observable

final class BrowserTab: Identifiable {

    let id: UUID

    let isPrivate: Bool

    var title: String

    var url: URL?

    var isHome: Bool

    var lastUsed = Date.now

    var session: BrowserSession?

    init(

        id: UUID = UUID(),

        isPrivate: Bool = false,

        title: String = "",

        url: URL? = nil,

        isHome: Bool = true

    ) {

        self.id = id

        self.isPrivate = isPrivate

        self.title = title

        self.url = url

        self.isHome = isHome

    }

    func capture() {

        guard let session else { return }

        title = session.title

        url = session.url ?? url

        isHome = session.isHome

    }

    func release() {

        capture()

        session?.close()

        session = nil

    }

}

@MainActor @Observable

final class BrowserTabManager {

    private(set) var tabs: [BrowserTab]

    private(set) var selectedID: UUID

    var persistenceError = false

    private(set) var closedTabs: [ClosedTab] = []

    @ObservationIgnored private var context: ModelContext?

    @ObservationIgnored private var data: BrowserDataService?

    @ObservationIgnored private var workspaceID = ""

    @ObservationIgnored private var privateStore: WKWebsiteDataStore?

    @ObservationIgnored private static var claimedWorkspaces: Set<String> = []

    struct ClosedTab {

        let title: String

        let url: URL?

        let isHome: Bool

    }

    init() {

        let tab = BrowserTab()

        tab.session = BrowserSession()

        tabs = [tab]

        selectedID = tab.id

    }

    var selectedTab: BrowserTab? { tabs.first { $0.id == selectedID } }

    var normalTabs: [BrowserTab] { tabs.filter { !$0.isPrivate } }

    var privateTabs: [BrowserTab] { tabs.filter(\.isPrivate) }

    /// SceneStorage restores a window's identity. A cold launch can reclaim an

    /// unclaimed persisted workspace without sharing a WKWebView between windows.

    func configure(

        context: ModelContext,

        data: BrowserDataService,

        suggestedWorkspaceID: String

    ) -> String {

        guard self.context == nil else { return workspaceID }

        self.context = context

        self.data = data

        do {

            let saved = try context.fetch(

                FetchDescriptor<PersistedBrowserTab>(sortBy: [

                    SortDescriptor(\.sortOrder)

                ])

            )

            let available = saved.first {

                !Self.claimedWorkspaces.contains($0.workspaceID)

            }?.workspaceID

            workspaceID =

                !suggestedWorkspaceID.isEmpty

                    && !Self.claimedWorkspaces.contains(suggestedWorkspaceID)

                ? suggestedWorkspaceID : available ?? UUID().uuidString

            Self.claimedWorkspaces.insert(workspaceID)

            let owned = saved.filter { $0.workspaceID == workspaceID }

            if UserDefaults.standard.object(forKey: "restoreTabs") as? Bool

                ?? true, !owned.isEmpty

            {

                tabs.forEach { $0.release() }

                tabs = owned.map {

                    BrowserTab(

                        id: $0.id,

                        title: $0.title,

                        url: $0.url.flatMap(URL.init(string:)),

                        isHome: $0.isHome

                    )

                }

                selectedID = owned.first(where: \.isSelected)?.id ?? tabs[0].id

            }

            if let tab = selectedTab { activate(tab) }

            persist()

        } catch { persistenceError = true }

        return workspaceID

    }

    func select(_ tab: BrowserTab) {

        selectedTab?.capture()

        selectedTab?.session?.finishDialog(nil)

        selectedID = tab.id

        tab.lastUsed = .now

        activate(tab)

        trimSessions()

        persist()

    }

    @discardableResult

    func add(isPrivate: Bool = false, url: URL? = nil) -> BrowserTab {

        let tab = BrowserTab(isPrivate: isPrivate, url: url, isHome: url == nil)

        tabs.append(tab)

        select(tab)

        return tab

    }

    func duplicate(_ tab: BrowserTab) {

        tab.capture()

        let copy = add(

            isPrivate: tab.isPrivate,

            url: tab.isHome ? nil : tab.url

        )

        copy.title = tab.title

        persist()

    }

    func close(_ tab: BrowserTab) {

        tab.capture()

        if !tab.isPrivate {

            closedTabs.insert(

                ClosedTab(title: tab.title, url: tab.url, isHome: tab.isHome),

                at: 0

            )

            closedTabs = Array(closedTabs.prefix(20))

        }

        let wasSelected = selectedID == tab.id

        tab.release()

        tabs.removeAll { $0.id == tab.id }

        if privateTabs.isEmpty {

            privateStore = nil

        }

        if tabs.isEmpty {

            add()

        } else if wasSelected,

            let next = tabs.last(where: { $0.isPrivate == tab.isPrivate })

                ?? tabs.last

        {

            select(next)

        }

        persist()

    }

    func closeAllNormalTabs() {

        let closing = normalTabs

        for tab in closing {

            tab.capture()

            closedTabs.insert(

                ClosedTab(title: tab.title, url: tab.url, isHome: tab.isHome),

                at: 0

            )

            tab.release()

        }

        closedTabs = Array(closedTabs.prefix(20))

        tabs.removeAll { !$0.isPrivate }

        if let next = tabs.last { select(next) } else { add() }

        persist()

    }

    func endPrivateSession() {

        privateTabs.forEach { $0.release() }

        tabs.removeAll(where: \.isPrivate)

        privateStore = nil

        if let next = normalTabs.last { select(next) } else { add() }

        persist()

    }

    func restoreClosedTab() {

        guard !closedTabs.isEmpty else { return }

        let closed = closedTabs.removeFirst()

        let tab = add(url: closed.isHome ? nil : closed.url)

        tab.title = closed.title

        persist()

    }

    func persist() {

        guard let context, !workspaceID.isEmpty else { return }

        tabs.forEach { $0.capture() }

        do {

            let owner = workspaceID

            let existing = try context.fetch(

                FetchDescriptor<PersistedBrowserTab>(

                    predicate: #Predicate { $0.workspaceID == owner }

                )

            )

            let shouldRestore =

                UserDefaults.standard.object(forKey: "restoreTabs") as? Bool

                ?? true

            let normal = shouldRestore ? normalTabs : []

            let ids = Set(normal.map(\.id))

            for record in existing where !ids.contains(record.id) {

                context.delete(record)

            }

            for (index, tab) in normal.enumerated() {

                if let record = existing.first(where: { $0.id == tab.id }) {

                    record.title = tab.title

                    record.url = tab.url?.absoluteString

                    record.isHome = tab.isHome

                    record.sortOrder = index

                    record.isSelected = tab.id == selectedID

                } else {

                    context.insert(

                        PersistedBrowserTab(

                            id: tab.id,

                            workspaceID: owner,

                            title: tab.title,

                            url: tab.url?.absoluteString,

                            isHome: tab.isHome,

                            sortOrder: index,

                            isSelected: tab.id == selectedID

                        )

                    )

                }

            }

            try context.save()

        } catch {

            context.rollback()

            persistenceError = true

        }

    }

    private func activate(_ tab: BrowserTab) {

        if tab.session == nil {

            if tab.isPrivate && privateStore == nil {

                privateStore = .nonPersistent()

            }

            let session = BrowserSession(

                dataStore: tab.isPrivate

                    ? privateStore ?? .nonPersistent() : .default()

            )

            tab.session = session

            wire(session, to: tab)

            if !tab.isHome, let url = tab.url { session.load(url) }

        } else if let session = tab.session {

            wire(session, to: tab)

        }

    }

    private func wire(_ session: BrowserSession, to tab: BrowserTab) {
        session.onPageFinished = { [weak self, weak tab] url, title in

            guard let self, let tab else { return }

            tab.capture()

            self.data?.recordVisit(

                url: url,

                title: title,

                isPrivate: tab.isPrivate

            )

            self.persist()

        }

        session.onStateChanged = { [weak self, weak tab] in

            tab?.capture()

            self?.persist()

        }

        session.onCreateWindow = { [weak self, weak tab] configuration in

            guard let self, let tab else { return nil }

            let newTab = BrowserTab(isPrivate: tab.isPrivate, isHome: false)

            let newSession = BrowserSession(configuration: configuration)

            newTab.session = newSession
            self.wire(newSession, to: newTab)

            self.tabs.append(newTab)

            self.select(newTab)

            return newSession.webView

        }

    }

    func detach() {

        persist()

        tabs.forEach { $0.release() }

        tabs.removeAll(where: \.isPrivate)

        if tabs.isEmpty { tabs = [BrowserTab()] }

        if !tabs.contains(where: { $0.id == selectedID }),

            let first = tabs.first

        {

            selectedID = first.id

        }

        privateStore = nil

        Self.claimedWorkspaces.remove(workspaceID)

        context = nil
        data = nil
        workspaceID = ""

    }

    func trimSessions() {

        // Suspended tabs keep metadata; reactivation reloads their current page.

        // The selected tab and in-flight loads are never evicted here.

        let idle = tabs.filter {

            $0.id != selectedID && $0.session != nil

                && $0.session?.isLoading != true

        }

        .sorted { $0.lastUsed < $1.lastUsed }

        let excess = max(0, tabs.filter { $0.session != nil }.count - 6)

        for tab in idle.prefix(excess) { tab.release() }

    }

}
