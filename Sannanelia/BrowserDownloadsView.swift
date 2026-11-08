//
//  BrowserDownloadsView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import AVKit
import SwiftUI

struct BrowserDownloadsView: View {
    let manager: BrowserDownloadManager
    let session: BrowserSession
    let isPrivate: Bool
    @State private var candidates: [BrowserMediaCandidate] = []
    @State private var scanning = false
    @State private var scanFailed = false
    @State private var directLink = ""
    @State private var playing: BrowserDownloadItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(
                        "Save videos and music for offline playback.",
                        systemImage: "play.rectangle.on.rectangle"
                    )
                    Text(
                        "Open a video or song on a website, then check this page. You can also paste a direct media link."
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(
                        "YouTube and some other players use protected or segmented streams. Those cannot be downloaded here."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                Section("On this page") {
                    Button {
                        Task { await scan() }
                    } label: {
                        Label(
                            "Find video and audio",
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(session.isHome || scanning)
                    if scanning { ProgressView("Looking for media") }
                    ForEach(candidates) { candidate in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    verbatim: candidate.title.isEmpty
                                        ? candidate.url.lastPathComponent
                                        : candidate.title
                                )
                                .lineLimit(2)
                                Text(verbatim: candidate.url.host ?? "").font(
                                    .caption
                                ).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                manager.startMedia(
                                    candidate.url,
                                    session: session,
                                    isPrivate: isPrivate
                                )
                            } label: {
                                Label(
                                    "Download",
                                    systemImage: "arrow.down.circle.fill"
                                ).labelStyle(.iconOnly)
                            }
                            .disabled(manager.isStarting)
                        }
                    }
                    if !scanning && candidates.isEmpty {
                        Text(
                            scanFailed
                                ? "The page could not be checked. Try again after it finishes loading."
                                : "No direct media file found. Start the video on the website and check again."
                        )
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section("Direct media link") {
                    TextField("Paste video or audio URL", text: $directLink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled().keyboardType(.URL)
                    Button("Download media", systemImage: "arrow.down.circle") {
                        let input = directLink.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        guard let url = URL(string: input),
                            BrowserMediaPolicy.isDirectURL(url)
                        else {
                            manager.mediaError =
                                "Use a direct video or audio link. Streaming playlists and protected players cannot be saved here."
                            return
                        }
                        manager.startMedia(
                            url,
                            session: session,
                            isPrivate: isPrivate
                        )
                    }
                    .disabled(
                        directLink.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty || manager.isStarting
                    )
                    if manager.isStarting { ProgressView("Starting download") }
                }
                Section("Saved on this device") {
                    if manager.items.isEmpty {
                        Text(
                            "Your downloaded videos and music will appear here."
                        )
                        .foregroundStyle(.secondary)
                    }
                    ForEach(manager.items) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(
                                    systemName: item.isPrivate
                                        ? "hand.raised" : "play.rectangle"
                                ).accessibilityHidden(true)
                                Text(
                                    item.filename.isEmpty
                                        ? String(localized: "Download")
                                        : item.filename
                                ).lineLimit(2)
                                Spacer()
                                if item.status == .downloading {
                                    Button("Cancel") { manager.cancel(item) }
                                }
                            }
                            Text(item.status.title).font(.caption)
                                .foregroundStyle(.secondary)
                            if let reason = item.failureMessage {
                                Text(verbatim: reason).font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if item.status == .downloading {
                                if item.totalBytes > 0 {
                                    ProgressView(value: item.fractionCompleted)
                                    Text(
                                        item.fractionCompleted,
                                        format: .percent.precision(
                                            .fractionLength(0)
                                        )
                                    ).font(.caption)
                                } else {
                                    ProgressView()
                                }
                            }
                            if item.status == .finished, let url = item.fileURL
                            {
                                if BrowserMediaPolicy.isMediaFile(url) {
                                    Button(
                                        "Play offline",
                                        systemImage: "play.fill"
                                    ) { playing = item }
                                    .buttonStyle(.borderedProminent)
                                }
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
            }
            .buttonStyle(.borderless)
            .navigationTitle("Video & audio downloads")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await scan() }
            .sheet(item: $playing) { item in
                if let url = item.fileURL {
                    BrowserOfflinePlayerView(url: url, title: item.filename)
                }
            }
            .alert(
                "Download unavailable",
                isPresented: Binding(
                    get: { manager.mediaError != nil || manager.storageError },
                    set: {
                        if !$0 {
                            manager.mediaError = nil
                            manager.storageError = false
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = manager.mediaError {
                    Text(error)
                } else {
                    Text("Check available storage and try again.")
                }
            }
        }
    }

    private func scan() async {
        guard !session.isHome else { return }
        scanning = true
        scanFailed = false
        defer { scanning = false }
        do { candidates = try await session.discoverMedia() } catch {
            candidates = []
            scanFailed = true
        }
    }
}

private struct BrowserOfflinePlayerView: View {
    let url: URL
    let title: String
    @State private var player: AVPlayer?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if failed {
                    ContentUnavailableView(
                        "Cannot play this file",
                        systemImage: "exclamationmark.triangle",
                        description: Text(
                            "The file is missing or its media format is not supported on this device."
                        )
                    )
                } else if let player {
                    VideoPlayer(player: player)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    guard FileManager.default.fileExists(atPath: url.path)
                    else {
                        failed = true
                        return
                    }
                    let asset = AVURLAsset(url: url)
                    guard try await asset.load(.isPlayable) else {
                        failed = true
                        return
                    }
                    try Task.checkCancellation()
                    let instance = AVPlayer(
                        playerItem: AVPlayerItem(asset: asset)
                    )
                    player = instance
                    instance.play()
                } catch is CancellationError {
                } catch { failed = true }
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }
}
