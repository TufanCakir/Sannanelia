//
//  BrowserTabGridView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI
import UIKit
import WebKit

/// Tab overview for Sannanelia. Uses each tab's existing BrowserSession/WKWebView.
struct BrowserTabGridView: View {
    let manager: BrowserTabManager

    @State private var isPrivate = false
    @State private var confirmsClosing = false
    @State private var snapshots: [UUID: UIImage] = [:]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleTabs: [BrowserTab] {
        isPrivate ? manager.privateTabs : manager.normalTabs
    }

    private let columns = [
        GridItem(.adaptive(minimum: 155, maximum: 270), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Browsing mode", selection: $isPrivate) {
                        Text("Tabs").tag(false)
                        Text("Private").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if isPrivate {
                        Text(
                            "Private tabs do not save browsing history. Websites and your internet provider can still see your activity."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if visibleTabs.isEmpty {
                        ContentUnavailableView(
                            "No tabs",
                            systemImage: isPrivate
                                ? "hand.raised" : "square.on.square"
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(visibleTabs) { tab in
                                BrowserSnapshotTabCard(
                                    tab: tab,
                                    snapshot: snapshots[tab.id],
                                    isSelected: tab.id == manager.selectedID,
                                    select: {
                                        manager.select(tab)
                                        dismiss()
                                    },
                                    close: { close(tab) },
                                    duplicate: {
                                        manager.duplicate(tab)
                                        dismiss()
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(ThemeManager.background(scheme))
            .navigationTitle(isPrivate ? "Private tabs" : "Tabs")
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: visibleTabs.count
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(
                            "Restore closed tab",
                            systemImage: "arrow.uturn.backward"
                        ) {
                            manager.restoreClosedTab()
                            dismiss()
                        }
                        .disabled(manager.closedTabs.isEmpty)

                        Button(
                            isPrivate
                                ? "End private session"
                                : "Close all normal tabs",
                            role: .destructive
                        ) {
                            confirmsClosing = true
                        }
                    } label: {
                        Label("Tab actions", systemImage: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("New tab", systemImage: "plus") {
                        manager.add(isPrivate: isPrivate)
                        dismiss()
                    }
                    .keyboardShortcut("t", modifiers: .command)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                isPrivate ? "End private session?" : "Close all normal tabs?",
                isPresented: $confirmsClosing,
                titleVisibility: .visible
            ) {
                Button("Close tabs", role: .destructive) {
                    if isPrivate {
                        manager.endPrivateSession()
                    } else {
                        manager.closeAllNormalTabs()
                    }
                    pruneSnapshots()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                isPrivate = manager.selectedTab?.isPrivate ?? false
                captureVisibleSnapshots()
            }
            .onChange(of: isPrivate) { _, _ in captureVisibleSnapshots() }
            .onChange(of: visibleTabs.map(\.id)) { _, _ in
                pruneSnapshots()
                captureVisibleSnapshots()
            }
            .onDisappear {
                // In particular, never retain private-tab screenshots after leaving the overview.
                snapshots.removeAll()
            }
        }
    }

    private func close(_ tab: BrowserTab) {
        snapshots.removeValue(forKey: tab.id)
        manager.close(tab)
    }

    private func pruneSnapshots() {
        let validIDs = Set(manager.tabs.map(\.id))
        snapshots = snapshots.filter { validIDs.contains($0.key) }
    }

    private func captureVisibleSnapshots() {
        for tab in visibleTabs where !tab.isHome {
            guard let webView = tab.session?.webView else { continue }
            let id = tab.id
            let config = WKSnapshotConfiguration()
            config.snapshotWidth = NSNumber(value: 360)
            // Capture only the visible viewport, not a potentially huge entire webpage.
            config.rect = webView.bounds
            guard config.rect.width > 0, config.rect.height > 0 else {
                continue
            }

            Task { @MainActor in
                guard
                    let image = try? await webView.takeSnapshot(
                        configuration: config
                    )
                else { return }
                // Ignore results from tabs closed or switched to the other browsing mode.
                guard manager.tabs.contains(where: { $0.id == id }) else {
                    return
                }
                snapshots[id] = image
            }
        }
    }
}

private struct BrowserSnapshotTabCard: View {
    let tab: BrowserTab
    let snapshot: UIImage?
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void
    let duplicate: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Button(action: select) {
                    ZStack {
                        ThemeManager.background(scheme)
                        if let snapshot {
                            Image(uiImage: snapshot)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .clipped()
                        } else {
                            VStack(spacing: 12) {
                                Image(
                                    systemName: tab.isHome
                                        ? BrowserAppearance.symbol(scheme)
                                        : "globe"
                                )
                                .contentTransition(.symbolEffect(.replace))
                                .font(.system(size: 42, weight: .ultraLight))
                                .foregroundStyle(ThemeManager.gold(scheme))
                                Text(
                                    tab.isHome
                                        ? "Sannanelia" : "Preview unavailable"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .clipped()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open tab")

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ThemeManager.foreground(scheme))
                        .frame(width: 36, height: 36)
                        .background(ThemeManager.surface(scheme), in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close tab")
                .padding(4)
            }

            Button(action: select) {
                HStack(spacing: 9) {
                    Image(
                        systemName: tab.isPrivate
                            ? "hand.raised"
                            : (tab.isHome
                                ? BrowserAppearance.symbol(scheme)
                                : "globe")
                    )
                    .foregroundStyle(ThemeManager.gold(scheme))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            verbatim: tab.isHome
                                ? "Home"
                                : (tab.title.isEmpty
                                    ? tab.url?.host ?? "Untitled" : tab.title)
                        )
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        Text(
                            verbatim: tab.isHome
                                ? "Sannanelia" : (tab.url?.host ?? "")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ThemeManager.gold(scheme))
                            .accessibilityLabel("Selected tab")
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(ThemeManager.foreground(scheme))
        .background(
            ThemeManager.surface(scheme),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isSelected
                        ? ThemeManager.gold(scheme)
                        : ThemeManager.gold(scheme).opacity(0.15),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .contextMenu {
            Button(
                "Duplicate tab",
                systemImage: "plus.square.on.square",
                action: duplicate
            )
            Button(
                "Close tab",
                systemImage: "xmark",
                role: .destructive,
                action: close
            )
        }
    }
}
