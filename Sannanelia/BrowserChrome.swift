//
//  BrowserChrome.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI
import UIKit
import WebKit

struct BrowserAddressBar: View {
    let session: BrowserSession
    let edit: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(
                    systemName: session.isHome
                        ? BrowserAppearance.symbol(scheme)
                        : (session.hasSecureContent ? "lock" : "lock.open")
                )
                .foregroundStyle(ThemeManager.accent(scheme))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(
                    session.isHome
                        ? Text("Home")
                        : (session.hasSecureContent
                            ? Text("Encrypted connection")
                            : Text("Connection is not fully secure"))
                )
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
                        if session.isLoading {
                            session.webView.stopLoading()
                        } else {
                            session.reload()
                        }
                    } label: {
                        Image(
                            systemName: session.isLoading
                                ? "xmark" : "arrow.clockwise"
                        )
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(
                        session.isLoading
                            ? Text("Stop loading") : Text("Reload")
                    )
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .frame(minHeight: 56)
            if session.isLoading && !session.isHome {
                ProgressView(value: session.progress)
                    .tint(ThemeManager.accent(scheme))
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.2),
                        value: session.progress
                    )
                    .accessibilityLabel("Loading page")
            }
        }
        .foregroundStyle(ThemeManager.foreground(scheme))
        .background(
            ThemeManager.surface(scheme),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct BrowserHomeView: View {
    let search: (String) -> Void
    let data: BrowserDataService
    let bookmarks: () -> Void
    let history: () -> Void
    let privateTab: () -> Void
    let downloads: () -> Void
    let open: (URL) -> Void
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {

                hero
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissKeyboard)

                searchButton

                shortcuts
                favoritesSection
                frequentlyVisitedSection
                Text(
                    scheme == .dark
                        ? "A little moonlight. A world to discover."
                        : "A little sunlight. A world to discover."
                )
                .font(.footnote)
                .foregroundStyle(ThemeManager.accent(scheme))
                .multilineTextAlignment(.center)
                .padding(.vertical, 18)
            }
            .padding(.horizontal, 22)
            .padding(.top, 30)
            .padding(.bottom, 40)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearchFocused = false
                }
        }
        .foregroundStyle(ThemeManager.foreground(scheme))
    }

    private func dismissKeyboard() {
        isSearchFocused = false
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: BrowserAppearance.symbol(scheme))
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 47, weight: .ultraLight))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(ThemeManager.gold(scheme))
                .frame(width: 112, height: 112)
                .background(ThemeManager.surface(scheme), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(
                            ThemeManager.gold(scheme).opacity(0.25),
                            lineWidth: 1
                        )
                }
                .accessibilityHidden(true)

            Text("Sannanelia")
                .font(.system(size: 38, weight: .medium, design: .serif))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Text(
                scheme == .dark
                    ? "Explore beneath the stars."
                    : "Discover with serenity."
            )
            .font(.subheadline)
            .foregroundStyle(ThemeManager.accent(scheme))
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var searchButton: some View {
        TextField("Search or enter address", text: $searchText)
            .focused($isSearchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.webSearch)
            .submitLabel(.go)
            .onSubmit {
                let input = searchText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !input.isEmpty else { return }

                isSearchFocused = false
                search(input)
                searchText = ""
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(
                ThemeManager.surface(scheme),
                in: RoundedRectangle(cornerRadius: 20)
            )
    }

    private var shortcuts: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            shortcut("Bookmarks", icon: "star", action: bookmarks)
            shortcut("History", icon: "clock.arrow.circlepath", action: history)
            shortcut("Downloads", icon: "arrow.down.circle", action: downloads)
            shortcut("Private tab", icon: "hand.raised", action: privateTab)
        }
    }

    private func shortcut(
        _ title: LocalizedStringKey,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(ThemeManager.gold(scheme))
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .background(
                ThemeManager.surface(scheme),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var favoritesSection: some View {
        if !data.bookmarks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Favorites", action: bookmarks)
                VStack(spacing: 2) {
                    ForEach(Array(data.bookmarks.prefix(6))) { bookmark in
                        Button {
                            if let url = URL(string: bookmark.url),
                                let scheme = url.scheme?.lowercased(),
                                ["https", "http"].contains(scheme)
                            {
                                open(url)
                            }
                        } label: {
                            BrowserLibraryRow(
                                title: bookmark.title,
                                url: bookmark.url,
                                symbol: "star"
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    ThemeManager.surface(scheme),
                    in: RoundedRectangle(cornerRadius: 20)
                )
            }
        }
    }

    @ViewBuilder
    private var frequentlyVisitedSection: some View {
        if !data.history.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Frequently visited", action: history)
                VStack(spacing: 2) {
                    ForEach(
                        Array(
                            data.history.sorted {
                                $0.visitCount > $1.visitCount
                            }.prefix(4)
                        )
                    ) { entry in
                        Button {
                            if let url = URL(string: entry.url),
                                let scheme = url.scheme?.lowercased(),
                                ["https", "http"].contains(scheme)
                            {
                                open(url)
                            }
                        } label: {
                            BrowserLibraryRow(
                                title: entry.title,
                                url: entry.url,
                                symbol: "globe"
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    ThemeManager.surface(scheme),
                    in: RoundedRectangle(cornerRadius: 20)
                )
            }
        }
    }

    private func sectionHeader(
        _ title: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: action) {
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ThemeManager.accent(scheme))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show all")
        }
    }
}

#Preview {
    BrowserHomeView(
        search: { _ in },
        data: BrowserDataService(),
        bookmarks: {},
        history: {},
        privateTab: {},
        downloads: {},
        open: { _ in }
    )
}

struct BrowserErrorView: View {
    let failure: BrowserFailure
    let retry: () -> Void
    let edit: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(failure.title)
            } icon: {
                Image(
                    systemName: BrowserAppearance.symbol(
                        scheme,
                        light: "sun.max",
                        dark: "moon"
                    )
                )
                .contentTransition(.symbolEffect(.replace))
            }
        } description: {
            Text(failure.message)
        } actions: {
            if case .invalidAddress = failure {
                Button("Edit address", action: edit).buttonStyle(
                    .borderedProminent
                )
            } else {
                Button("Try again", action: retry).buttonStyle(
                    .borderedProminent
                )
                Button("Edit address", action: edit)
            }
        }
    }
}

/// Replace only the existing BrowserNavigationBar with this view.
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
    let developerTools: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var canGoBack: Bool {
        session.canGoBack || (session.isHome && session.url != nil)
    }

    private var hasPage: Bool {
        !session.isHome && session.url != nil
    }

    var body: some View {
        HStack(spacing: 4) {
            navigationButton(
                "Back",
                symbol: "chevron.backward",
                enabled: canGoBack
            ) {
                session.back()
            }
            .keyboardShortcut("[", modifiers: .command)

            navigationButton(
                "Forward",
                symbol: "chevron.forward",
                enabled: !session.isHome && session.canGoForward
            ) {
                session.forward()
            }
            .keyboardShortcut("]", modifiers: .command)

            Spacer(minLength: 0)

            navigationButton(
                "Home",
                symbol: BrowserAppearance.symbol(scheme),
                enabled: !session.isHome
            ) {
                session.goHome()
            }
            .foregroundStyle(ThemeManager.gold(scheme))

            Spacer(minLength: 0)

            Button(action: tabs) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            ThemeManager.accent(scheme),
                            lineWidth: 1.5
                        )
                        .frame(width: 25, height: 25)
                    Text(manager.tabs.count, format: .number)
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(width: 21)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Tabs")
            .accessibilityValue(Text(manager.tabs.count, format: .number))

            Menu {
                Section {
                    Button("New tab", systemImage: "plus") { manager.add() }
                        .keyboardShortcut("t", modifiers: .command)
                    Button("Private tab", systemImage: "hand.raised") {
                        manager.add(isPrivate: true)
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    Button("Close tab", systemImage: "xmark") {
                        if let tab = manager.selectedTab { manager.close(tab) }
                    }
                    .disabled(manager.selectedTab == nil)
                    .keyboardShortcut("w", modifiers: .command)
                }

                Section {
                    Button("Reload", systemImage: "arrow.clockwise") {
                        session.reload()
                    }
                    .disabled(!hasPage)
                    .keyboardShortcut("r", modifiers: .command)

                    Button(
                        "Find on page",
                        systemImage: "magnifyingglass",
                        action: find
                    )
                    .disabled(!hasPage)
                    .keyboardShortcut("f", modifiers: .command)

                    Button(
                        session.desktopMode
                            ? "Request mobile website"
                            : "Request desktop website",
                        systemImage: "desktopcomputer"
                    ) {
                        session.setDesktopMode(!session.desktopMode)
                    }
                    .disabled(!hasPage)
                }

                if let url = session.url, hasPage {
                    Section {
                        Button("Copy link", systemImage: "doc.on.doc") {
                            UIPasteboard.general.url = url
                        }
                        ShareLink(item: url) {
                            Label(
                                "Share website",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        Button("Add bookmark", systemImage: "star") {
                            data.addBookmark(title: session.title, url: url)
                        }
                    }
                }

                Section {
                    Button("Bookmarks", systemImage: "star", action: bookmarks)
                    Button("History", systemImage: "clock", action: history)
                    Button(
                        "Downloads",
                        systemImage: "arrow.down.circle",
                        action: downloads
                    )
                }

                Section {
                    Button(
                        "Developer Tools",
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        action: developerTools
                    )
                    .disabled(!hasPage)

                    Button(
                        "Settings",
                        systemImage: "gear",
                        action: settings
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More options")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.title3)
        .foregroundStyle(ThemeManager.foreground(scheme))
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 8 : 12)
        .frame(minHeight: 56)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ThemeManager.surface(scheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    ThemeManager.gold(scheme).opacity(0.16),
                    lineWidth: 1
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private func navigationButton(
        _ title: LocalizedStringKey,
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

#Preview("Navigation Bar") {
    BrowserNavigationBar(
        session: BrowserSession(),
        manager: BrowserTabManager(),
        data: BrowserDataService(),
        tabs: {},
        bookmarks: {},
        history: {},
        downloads: {},
        find: {},
        settings: {},
        developerTools: {}
    )
    .padding()
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
                        ForEach(
                            Array(
                                data.bookmarks.filter {
                                    $0.title.localizedCaseInsensitiveContains(
                                        text
                                    )
                                        || $0.url
                                            .localizedCaseInsensitiveContains(
                                                text
                                            )
                                }.prefix(4)
                            )
                        ) { bookmark in
                            Button {
                                submit(bookmark.url)
                                dismiss()
                            } label: {
                                BrowserLibraryRow(
                                    title: bookmark.title,
                                    url: bookmark.url,
                                    symbol: "star"
                                )
                            }
                        }
                        ForEach(
                            Array(
                                data.history.filter {
                                    $0.title.localizedCaseInsensitiveContains(
                                        text
                                    )
                                        || $0.url
                                            .localizedCaseInsensitiveContains(
                                                text
                                            )
                                }.prefix(4)
                            )
                        ) { entry in
                            Button {
                                submit(entry.url)
                                dismiss()
                            } label: {
                                BrowserLibraryRow(
                                    title: entry.title,
                                    url: entry.url,
                                    symbol: "clock"
                                )
                            }
                        }
                    }
                }
                Section {
                    Button("Open", systemImage: "arrow.up.right", action: open)
                        .disabled(
                            text.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        )
                } footer: {
                    Text(
                        "Your typing stays on this device until you open a website or submit a search."
                    )
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        isFocused = false
                    }
                }
            }
            .onAppear {
                text = initialText
                isFocused = true
            }
        }
    }

    private func open() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        isFocused = false
        submit(text)
        dismiss()
    }
}

#Preview("Browser Error") {
    BrowserErrorView(
        failure: .invalidAddress,
        retry: {},
        edit: {}
    )
}
