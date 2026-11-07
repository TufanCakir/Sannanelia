import SwiftUI
import WebKit
import UIKit

struct BrowserAddressBar: View {
    let session: BrowserSession
    let edit: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: session.isHome ? "sun.max" : (session.hasSecureContent ? "lock" : "lock.open"))
                    .foregroundStyle(ThemeManager.accent(scheme))
                    .accessibilityLabel(session.isHome ? Text("Home") :
                        (session.hasSecureContent ? Text("Encrypted connection") : Text("Connection is not fully secure")))
                Button(action: edit) {
                    if session.isHome {
                        Text("Search or enter address")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(verbatim: session.url?.host ?? session.title)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search or enter address")
                .keyboardShortcut("l", modifiers: .command)
                if !session.isHome {
                    Button {
                        if session.isLoading { session.webView.stopLoading() }
                        else { session.reload() }
                    } label: {
                        Image(systemName: session.isLoading ? "xmark" : "arrow.clockwise")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(session.isLoading ? Text("Stop loading") : Text("Reload"))
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .frame(minHeight: 56)
            if session.isLoading && !session.isHome {
                ProgressView(value: session.progress)
                    .tint(ThemeManager.accent(scheme))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.progress)
                    .accessibilityLabel("Loading page")
            }
        }
        .foregroundStyle(ThemeManager.foreground(scheme))
        .background(ThemeManager.surface(scheme), in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct BrowserHomeView: View {
    let search: () -> Void
    let data: BrowserDataService
    let bookmarks: () -> Void
    let history: () -> Void
    let privateTab: () -> Void
    let downloads: () -> Void
    let open: (URL) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max").accessibilityHidden(true)
                    Text("SANNANELIA").font(.caption.weight(.semibold)).tracking(3)
                }
                .foregroundStyle(ThemeManager.accent(scheme))
                .padding(.top, 32)

                Spacer(minLength: 30)
                Image(systemName: "sun.max")
                    .font(.system(.largeTitle, design: .rounded).weight(.ultraLight))
                    .padding(30)
                    .background(ThemeManager.surface(scheme), in: Circle())
                    .foregroundStyle(ThemeManager.gold(scheme))
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Sannanelia")
                        .font(.system(.largeTitle, design: .serif).weight(.medium))
                        .accessibilityAddTraits(.isHeader)
                    Text("Discover with serenity.")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.accent(scheme))
                        .multilineTextAlignment(.center)
                }

                Button(action: search) {
                    Label("Begin exploring", systemImage: "magnifyingglass")
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
                .background(ThemeManager.surface(scheme), in: Capsule())
                .padding(.top, 12)

                ViewThatFits {
                    HStack(spacing: 20) { quickLinks }
                    VStack(spacing: 16) { quickLinks }
                }
                if !data.bookmarks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorites").font(.headline)
                        ForEach(Array(data.bookmarks.prefix(6))) { bookmark in
                            Button {
                                if let url = URL(string: bookmark.url) { open(url) }
                            } label: {
                                BrowserLibraryRow(title: bookmark.title, url: bookmark.url, symbol: "star")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !data.history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frequently visited").font(.headline)
                        ForEach(Array(data.history.sorted { $0.visitCount > $1.visitCount }.prefix(4))) { entry in
                            Button {
                                if let url = URL(string: entry.url) { open(url) }
                            } label: {
                                BrowserLibraryRow(title: entry.title, url: entry.url, symbol: "globe")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("A little sunlight. A world to discover.")
                    .font(.footnote)
                    .foregroundStyle(ThemeManager.accent(scheme))
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                Spacer(minLength: 30)
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }
    private var quickLinks: some View {
        Group {
            Button("Bookmarks", systemImage: "star", action: bookmarks)
            Button("History", systemImage: "clock", action: history)
            Button("Downloads", systemImage: "arrow.down.circle", action: downloads)
            Button("Private tab", systemImage: "hand.raised", action: privateTab)
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }
}

struct BrowserErrorView: View {
    let failure: BrowserFailure
    let retry: () -> Void
    let edit: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label { Text(failure.title) } icon: { Image(systemName: "sun.haze") }
        } description: {
            Text(failure.message)
        } actions: {
            if case .invalidAddress = failure {
                Button("Edit address", action: edit).buttonStyle(.borderedProminent)
            } else {
                Button("Try again", action: retry).buttonStyle(.borderedProminent)
                Button("Edit address", action: edit)
            }
        }
    }
}

struct BrowserNavigationBar: View {
    let session: BrowserSession
    let manager: BrowserTabManager
    let data: BrowserDataService
    let tabs: () -> Void
    let bookmarks: () -> Void
    let history: () -> Void
    let downloads: () -> Void
    let find: () -> Void
    let settings: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 4) {
            Button(action: session.back) {
                Label("Back", systemImage: "chevron.backward").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!session.canGoBack && !(session.isHome && session.url != nil))
            .keyboardShortcut("[", modifiers: .command)
            Spacer(minLength: 0)
            Button(action: session.forward) {
                Label("Forward", systemImage: "chevron.forward").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(session.isHome || !session.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
            Spacer(minLength: 0)
            Button(action: session.goHome) {
                Label("Home", systemImage: "sun.max").frame(minWidth: 44, minHeight: 44)
            }
            Spacer(minLength: 0)
            Button(action: tabs) {
                Text(manager.tabs.count, format: .number)
                    .font(.body.weight(.semibold))
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(lineWidth: 1.5))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Tabs")
            .accessibilityValue(Text(manager.tabs.count, format: .number))
            Spacer(minLength: 0)
            Menu {
                Button("New tab", systemImage: "plus") { manager.add() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Private tab", systemImage: "hand.raised") { manager.add(isPrivate: true) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Close tab", systemImage: "xmark") {
                    if let tab = manager.selectedTab { manager.close(tab) }
                }
                .keyboardShortcut("w", modifiers: .command)
                Button("Reload", systemImage: "arrow.clockwise", action: session.reload)
                    .disabled(session.isHome)
                    .keyboardShortcut("r", modifiers: .command)
                if let url = session.url, !session.isHome {
                    Button("Copy link", systemImage: "doc.on.doc") { UIPasteboard.general.url = url }
                    ShareLink(item: url) { Label("Share website", systemImage: "square.and.arrow.up") }
                }
                Button("Add bookmark", systemImage: "star") {
                    if let url = session.url { data.addBookmark(title: session.title, url: url) }
                }
                .disabled(session.isHome || session.url == nil)
                Button("Find on page", systemImage: "magnifyingglass", action: find)
                    .disabled(session.isHome)
                    .keyboardShortcut("f", modifiers: .command)
                Button(session.desktopMode ? "Request mobile website" : "Request desktop website", systemImage: "desktopcomputer") {
                    session.setDesktopMode(!session.desktopMode)
                }
                .disabled(session.isHome)
                Button("Downloads", systemImage: "arrow.down.circle", action: downloads)
                Button("Bookmarks", systemImage: "star", action: bookmarks)
                Button("History", systemImage: "clock", action: history)
                Button("Settings", systemImage: "gearshape", action: settings)
            } label: {
                Label("More", systemImage: "ellipsis").frame(minWidth: 44, minHeight: 44)
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.title3)
        .frame(minHeight: 56)
        .padding(.horizontal, 16)
        .background(ThemeManager.surface(scheme), in: RoundedRectangle(cornerRadius: 26))
        .foregroundStyle(ThemeManager.foreground(scheme))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

struct BrowserSearchView: View {
    let initialText: String
    let data: BrowserDataService
    let submit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Search or enter address", text: $text)
                    .textContentType(.URL)
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit(open)
                if !text.isEmpty {
                    Section("On this device") {
                        ForEach(Array(data.bookmarks.filter {
                            $0.title.localizedCaseInsensitiveContains(text) || $0.url.localizedCaseInsensitiveContains(text)
                        }.prefix(4))) { bookmark in
                            Button {
                                submit(bookmark.url)
                                dismiss()
                            } label: { BrowserLibraryRow(title: bookmark.title, url: bookmark.url, symbol: "star") }
                        }
                        ForEach(Array(data.history.filter {
                            $0.title.localizedCaseInsensitiveContains(text) || $0.url.localizedCaseInsensitiveContains(text)
                        }.prefix(4))) { entry in
                            Button {
                                submit(entry.url)
                                dismiss()
                            } label: { BrowserLibraryRow(title: entry.title, url: entry.url, symbol: "clock") }
                        }
                    }
                }
                Section {
                    Button("Open", systemImage: "arrow.up.right", action: open)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Your typing stays on this device until you open a website or submit a search.")
                }
            }
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                text = initialText
                isFocused = true
            }
        }
    }

    private func open() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        submit(text)
        dismiss()
    }
}
