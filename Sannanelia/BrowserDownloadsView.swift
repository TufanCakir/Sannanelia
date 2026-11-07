//
//  BrowserDownloadsView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI

struct BrowserDownloadsView: View {
    let manager: BrowserDownloadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.items) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(
                                systemName: item.isPrivate
                                    ? "hand.raised" : "doc"
                            ).accessibilityHidden(true)
                            if item.filename.isEmpty {
                                Text("Download")
                            } else {
                                Text(verbatim: item.filename).lineLimit(2)
                            }
                            Spacer()
                            if item.status == .downloading {
                                Button("Cancel") { manager.cancel(item) }
                            }
                        }
                        Text(item.status.title).font(.caption).foregroundStyle(
                            .secondary
                        )
                        if item.status == .downloading {
                            if item.totalBytes > 0 {
                                ProgressView(value: item.fractionCompleted)
                            } else {
                                ProgressView()
                            }
                        }
                        if item.status == .finished, let url = item.fileURL {
                            ShareLink(item: url) {
                                Label(
                                    "Share or save file",
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                        }
                        if item.isPrivate {
                            Text(
                                "This file is temporary. Save a copy before ending private browsing."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            manager.delete(item)
                        }
                    }
                }
            }
            .overlay {
                if manager.items.isEmpty {
                    ContentUnavailableView(
                        "No downloads",
                        systemImage: "arrow.down.circle"
                    )
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Download files could not be updated",
                isPresented: Binding(
                    get: { manager.storageError },
                    set: { manager.storageError = $0 }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check available storage and try again.")
            }
        }
    }
}
