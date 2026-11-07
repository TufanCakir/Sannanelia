import SwiftUI

struct BrowserTabGridView: View {
    let manager: BrowserTabManager
    @State private var isPrivate = false
    @State private var confirmsClosing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleTabs: [BrowserTab] { isPrivate ? manager.privateTabs : manager.normalTabs }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Browsing mode", selection: $isPrivate) {
                        Text("Tabs").tag(false)
                        Text("Private").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if isPrivate {
                        Text("Private tabs do not save browsing history. Websites and your internet provider can still see your activity.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                        ForEach(visibleTabs) { tab in
                            BrowserTabCard(tab: tab, isSelected: tab.id == manager.selectedID,
                                           select: { manager.select(tab); dismiss() },
                                           close: { manager.close(tab) },
                                           duplicate: { manager.duplicate(tab); dismiss() })
                        }
                    }
                    if visibleTabs.isEmpty {
                        ContentUnavailableView("No tabs", systemImage: isPrivate ? "hand.raised" : "square.on.square")
                    }
                }
                .padding()
            }
            .background(ThemeManager.background(scheme))
            .navigationTitle(isPrivate ? "Private tabs" : "Tabs")
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: visibleTabs.count)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Restore closed tab", systemImage: "arrow.uturn.backward") {
                            manager.restoreClosedTab()
                            dismiss()
                        }
                        .disabled(manager.closedTabs.isEmpty)
                        Button(isPrivate ? "End private session" : "Close all normal tabs", role: .destructive) {
                            confirmsClosing = true
                        }
                    } label: { Label("Tab actions", systemImage: "ellipsis.circle") }
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
            .confirmationDialog(isPrivate ? "End private session?" : "Close all normal tabs?",
                                isPresented: $confirmsClosing, titleVisibility: .visible) {
                Button("Close tabs", role: .destructive) {
                    if isPrivate { manager.endPrivateSession() }
                    else { manager.closeAllNormalTabs() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { isPrivate = manager.selectedTab?.isPrivate ?? false }
        }
    }
}

private struct BrowserTabCard: View {
    let tab: BrowserTab
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void
    let duplicate: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: tab.isPrivate ? "hand.raised" : "sun.max").accessibilityHidden(true)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").accessibilityLabel("Selected tab")
                }
                Button(action: close) {
                    Label("Close tab", systemImage: "xmark").labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            Button(action: select) {
                VStack(alignment: .leading, spacing: 8) {
                    if tab.isHome { Text("Home").font(.headline) }
                    else { Text(verbatim: tab.title.isEmpty ? tab.url?.host ?? "" : tab.title).font(.headline).lineLimit(2) }
                    Text(verbatim: tab.isHome ? "Sannanelia" : tab.url?.host ?? "")
                        .font(.caption).lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .foregroundStyle(ThemeManager.foreground(scheme))
        .background(ThemeManager.surface(scheme), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(
                isSelected ? ThemeManager.accent(scheme) : .clear, lineWidth: 2)
        }
        .contextMenu {
            Button("Duplicate tab", systemImage: "plus.square.on.square", action: duplicate)
            Button("Close tab", systemImage: "xmark", role: .destructive, action: close)
        }
    }
}
