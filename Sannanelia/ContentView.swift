//
//  ContentView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var manager = BrowserTabManager()
    @State private var data = BrowserDataService()
    @SceneStorage("browserWorkspaceID") private var workspaceID = ""
    @AppStorage("language") private var language = "system"
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let session = manager.selectedTab?.session {
                BrowserWorkspaceView(
                    session: session,
                    manager: manager,
                    data: data
                )
            } else {
                ProgressView()
            }
        }
        .environment(
            \.locale,
            language == "system"
                ? .autoupdatingCurrent : Locale(identifier: language)
        )
        .task {
            data.configure(context)
            workspaceID = manager.configure(
                context: context,
                data: data,
                suggestedWorkspaceID: workspaceID
            )
        }
        .onDisappear { manager.detach() }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                manager.persist()
            } else {
                data.refresh()
            }
        }
    }
}

private struct BrowserWorkspaceView: View {
    let session: BrowserSession
    let manager: BrowserTabManager
    let data: BrowserDataService
    @State private var sheet: BrowserSheet?
    @State private var promptText = ""
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("searchEngine") private var searchEngine = BrowserSearchEngine
        .google.rawValue
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private enum BrowserSheet: String, Identifiable {
        case search, settings, tabs, bookmarks, history, downloads, find,
            developerTools
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            ThemeManager.background(scheme).ignoresSafeArea()
            if session.isHome {
                BrowserHomeView(
                    search: { input in
                        session.navigate(
                            input,
                            engine: BrowserSearchEngine(rawValue: searchEngine)
                                ?? .google
                        )
                    },
                    data: data,
                    bookmarks: { sheet = .bookmarks },
                    history: { sheet = .history },
                    privateTab: { manager.add(isPrivate: true) },
                    downloads: { sheet = .downloads },
                    open: session.load
                )
            } else if let failure = session.failure {
                BrowserErrorView(failure: failure, retry: session.reload) {
                    sheet = .search
                }
            } else {
                // Detach hidden WebKit content from the remote accessibility tree.
                // Each tab retains its WKWebView independently of this view.
                BrowserWebView(session: session).id(manager.selectedID)
            }
        }
        .foregroundStyle(ThemeManager.foreground(scheme))
        .tint(ThemeManager.accent(scheme))
        .overlay {
            if !session.isHome,
                session.failure == nil,
                let video = session.detectedVideo
            {

                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    BrowserVideoDownloadOverlay(
                        video: video,
                        download: {
                            if let url = video.url,
                                BrowserMediaPolicy.isDirectURL(url)
                            {

                                manager.downloads.startMedia(
                                    url,
                                    session: session,
                                    isPrivate: manager.selectedTab?.isPrivate
                                        ?? false
                                )
                            }

                            session.detectedVideo = nil
                        },
                        cancel: {
                            session.detectedVideo = nil
                        },
                        canDownload: video.url.map {
                            BrowserMediaPolicy.isDirectURL($0)
                        } ?? false
                    )
                }
                .transition(
                    .opacity.combined(with: .scale(scale: 0.95))
                )
                .zIndex(10)
            }
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: session.detectedVideo != nil
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if manager.selectedTab?.isPrivate == true {
                    Label("Private browsing", systemImage: "hand.raised")
                        .font(.caption.weight(.semibold)).padding(.top, 4)
                }
                BrowserAddressBar(session: session) { sheet = .search }
                if !session.isHome {
                    Button {
                        sheet = .downloads
                    } label: {
                        Label(
                            "Save video or music",
                            systemImage: "arrow.down.circle"
                        )
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 8)
                    }
                    .accessibilityIdentifier("mediaDownloads")
                }
                if data.storageError || manager.persistenceError {
                    HStack {
                        Text("Changes could not be saved").font(.caption)
                        Button("Dismiss") {
                            data.storageError = false
                            manager.persistenceError = false
                        }
                    }
                    .padding(8)
                }
            }
            .background(ThemeManager.background(scheme))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BrowserNavigationBar(
                session: session,
                manager: manager,
                data: data,
                tabs: { sheet = .tabs },
                bookmarks: { sheet = .bookmarks },
                history: { sheet = .history },
                downloads: { sheet = .downloads },
                find: { sheet = .find },
                settings: { sheet = .settings },
                developerTools: { sheet = .developerTools }
            )
            .background(ThemeManager.background(scheme))
        }
        .preferredColorScheme(
            appearance == "system"
                ? nil : (appearance == "dark" ? .dark : .light)
        )
        .sensoryFeedback(.selection, trigger: manager.selectedID)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .search:
                BrowserSearchView(
                    initialText: session.isHome
                        ? "" : session.url?.absoluteString ?? "",
                    data: data
                ) { input in
                    session.navigate(
                        input,
                        engine: BrowserSearchEngine(rawValue: searchEngine)
                            ?? .google
                    )
                }
            case .downloads:
                BrowserDownloadsView(
                    manager: manager.downloads,
                    session: session,
                    isPrivate: manager.selectedTab?.isPrivate ?? false
                )
            case .find: BrowserFindView(session: session)
            case .settings: BrowserSettingsView(data: data, manager: manager)
            case .tabs: BrowserTabGridView(manager: manager)
            case .bookmarks:
                BrowserBookmarksView(data: data, open: session.load)
            case .history: BrowserHistoryView(data: data, open: session.load)
            case .developerTools:
                BrowserDeveloperToolsView(session: session)
            }
        }
        .onChange(of: manager.downloads.items.count) { oldCount, newCount in
            if newCount > oldCount { sheet = .downloads }
        }
        .onChange(of: session.dialog?.id) {
            promptText = session.dialog?.defaultText ?? ""
        }
        .alert(
            session.dialog?.host ?? "",
            isPresented: Binding(
                get: { session.dialog != nil },
                set: { if !$0 { session.finishDialog(nil) } }
            ),
            presenting: session.dialog
        ) { dialog in
            if dialog.kind == .prompt {
                TextField("Response", text: $promptText)
            }
            Button("OK") {
                session.finishDialog(dialog.kind == .prompt ? promptText : "")
            }
            if dialog.kind != .alert {
                Button("Cancel", role: .cancel) { session.finishDialog(nil) }
            }
        } message: { dialog in
            Text(verbatim: dialog.message)
        }
        .confirmationDialog(
            "Open another app?",
            isPresented: Binding(
                get: { session.externalURL != nil },
                set: { if !$0 { session.externalURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let url = session.externalURL {
                Button("Open") {
                    session.externalURL = nil
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { session.externalURL = nil }
        } message: {
            Text(verbatim: session.externalURL?.absoluteString ?? "")
        }
        .overlay {
            if scenePhase != .active && manager.selectedTab?.isPrivate == true {
                ThemeManager.background(scheme).ignoresSafeArea()
                    .overlay {
                        Label("Private browsing", systemImage: "hand.raised")
                            .font(.title2)
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
