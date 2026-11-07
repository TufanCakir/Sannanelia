//
//  BrowserLibraryViews.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI

struct BrowserBookmarksView: View {
    let data: BrowserDataService
    let open: (URL) -> Void
    @State private var query = ""
    @State private var editing: BrowserBookmark?
    @State private var adding = false
    @Environment(\.dismiss) private var dismiss

    private var results: [BrowserBookmark] {
        data.bookmarks.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { bookmark in
                    Button {
                        if let url = URL(string: bookmark.url) {
                            open(url)
                            dismiss()
                        }
                    } label: {
                        BrowserLibraryRow(
                            title: bookmark.title,
                            url: bookmark.url,
                            symbol: "star"
                        )
                    }
                    .contextMenu {
                        Button("Edit bookmark", systemImage: "pencil") {
                            editing = bookmark
                        }
                        Button(
                            "Delete bookmark",
                            systemImage: "trash",
                            role: .destructive
                        ) { data.deleteBookmark(bookmark) }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            data.deleteBookmark(bookmark)
                        }
                        Button("Edit") { editing = bookmark }.tint(.orange)
                    }
                }
                .onMove { offsets, destination in
                    if query.isEmpty {
                        data.moveBookmarks(from: offsets, to: destination)
                    }
                }
                .moveDisabled(!query.isEmpty)
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No bookmarks",
                        systemImage: "star",
                        description: Text(
                            "Save websites here to find them again."
                        )
                    )
                }
            }
            .searchable(text: $query, prompt: "Search bookmarks")
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton().disabled(!query.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add bookmark", systemImage: "plus") {
                        adding = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { bookmark in
                BrowserBookmarkEditor(data: data, bookmark: bookmark)
            }
            .sheet(isPresented: $adding) {
                BrowserBookmarkEditor(data: data, bookmark: nil)
            }
        }
    }
}

private struct BrowserBookmarkEditor: View {
    let data: BrowserDataService
    let bookmark: BrowserBookmark?
    @State private var title = ""
    @State private var address = ""
    @State private var invalidAddress = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Website address", text: $address)
                    .keyboardType(.URL).textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if invalidAddress {
                    Text("Enter a valid HTTP or HTTPS address.")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(bookmark == nil ? "Add bookmark" : "Edit bookmark")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let input = address.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        let candidate =
                            input.contains("://") ? input : "https://" + input
                        guard let url = URL(string: candidate),
                            let host = url.host, !host.isEmpty,
                            ["http", "https"].contains(
                                url.scheme?.lowercased() ?? ""
                            ),
                            url.user == nil, url.password == nil,
                            input.rangeOfCharacter(
                                from: .whitespacesAndNewlines
                            ) == nil
                        else {
                            invalidAddress = true
                            return
                        }
                        if let bookmark {
                            data.editBookmark(bookmark, title: title, url: url)
                        } else {
                            data.addBookmark(title: title, url: url)
                        }
                        if !data.storageError { dismiss() }
                    }
                    .disabled(
                        address.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
            .onAppear {
                title = bookmark?.title ?? ""
                address = bookmark?.url ?? ""
            }
            .alert(
                "Changes could not be saved",
                isPresented: Binding(
                    get: { data.storageError },
                    set: { data.storageError = $0 }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "Check available storage and make sure this bookmark address is not already saved."
                )
            }
        }
    }
}

struct BrowserHistoryView: View {
    let data: BrowserDataService
    let open: (URL) -> Void
    @State private var query = ""
    @State private var confirmsClear = false
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(day: Date, entries: [BrowserHistoryEntry])] {
        let filtered = data.history.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.url.localizedCaseInsensitiveContains(query)
        }
        return Dictionary(grouping: filtered) {
            Calendar.current.startOfDay(for: $0.visitedAt)
        }
        .map { (day: $0.key, entries: $0.value) }
        .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            Button {
                                if let url = URL(string: entry.url) {
                                    open(url)
                                    dismiss()
                                }
                            } label: {
                                BrowserLibraryRow(
                                    title: entry.title,
                                    url: entry.url,
                                    symbol: "clock"
                                )
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    data.deleteHistory(entry)
                                }
                            }
                        }
                    } header: {
                        Text(group.day, format: .dateTime.day().month().year())
                    }
                }
            }
            .overlay {
                if grouped.isEmpty {
                    ContentUnavailableView("No history", systemImage: "clock")
                }
            }
            .searchable(text: $query, prompt: "Search history")
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear history", role: .destructive) {
                        confirmsClear = true
                    }.disabled(data.history.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Clear browsing history?",
                isPresented: $confirmsClear,
                titleVisibility: .visible
            ) {
                Button("Clear history", role: .destructive) {
                    data.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This removes your visit list. Cookies and website data are kept."
                )
            }
        }
    }
}

struct BrowserLibraryRow: View {
    let title: String
    let url: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    verbatim: title.isEmpty
                        ? URL(string: url)?.host ?? url : title
                )
                .font(.body).foregroundStyle(.primary).lineLimit(2)
                Text(verbatim: URL(string: url)?.host ?? url)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
