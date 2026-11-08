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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Library") {
                    NavigationLink {
                        BrowserMusicLibraryView(manager: manager)
                    } label: {
                        Label(
                            "Music & Playlists",
                            systemImage: "music.note.list"
                        )
                    }
                }

                pageMediaSection
                directLinkSection
                downloadsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if scanning {
                        ProgressView()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await scan()
            }
            .task {
                await scan()
            }
            .alert(
                "Download unavailable",
                isPresented: Binding(
                    get: {
                        manager.mediaError != nil || manager.storageError
                    },
                    set: { presented in
                        if !presented {
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

    // MARK: - Media on Website

    private var pageMediaSection: some View {
        Section {
            Button {
                Task { await scan() }
            } label: {
                Label(
                    "Find video and audio",
                    systemImage: "magnifyingglass"
                )
            }
            .disabled(session.isHome || scanning)

            if scanning {
                HStack {
                    ProgressView()
                    Text("Looking for media")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(candidates) { candidate in
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            verbatim: candidate.title.isEmpty
                                ? candidate.url.lastPathComponent
                                : candidate.title
                        )
                        .font(.body)
                        .lineLimit(2)

                        Text(verbatim: candidate.url.host ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Button {
                        manager.startMedia(
                            candidate.url,
                            session: session,
                            isPrivate: isPrivate
                        )
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                    }
                    .disabled(manager.isStarting)
                    .accessibilityLabel("Download")
                }
            }

            if !scanning && candidates.isEmpty {
                ContentUnavailableView {
                    Label(
                        "No media found",
                        systemImage: "play.slash"
                    )
                } description: {
                    Text(
                        scanFailed
                            ? "The website could not be checked."
                            : "Start a video on the website and try again."
                    )
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("On this page")
        } footer: {
            Text(
                "Direct media files can be saved. Some streaming services and protected videos are not supported."
            )
        }
    }

    // MARK: - Direct URL

    private var directLinkSection: some View {
        Section {
            TextField(
                "Video or audio URL",
                text: $directLink
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .textContentType(.URL)
            .submitLabel(.done)
            .onSubmit(startDirectDownload)

            Button {
                startDirectDownload()
            } label: {
                Label(
                    "Download from URL",
                    systemImage: "arrow.down.circle"
                )
            }
            .disabled(
                directLink.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty || manager.isStarting
            )

            if manager.isStarting {
                ProgressView("Starting download")
            }
        } header: {
            Text("Direct link")
        } footer: {
            Text("Enter a direct link to a supported media file.")
        }
    }

    // MARK: - Saved Downloads

    private var downloadsSection: some View {
        Section("Saved on this device") {
            if manager.items.isEmpty {
                ContentUnavailableView(
                    "No downloads yet",
                    systemImage: "arrow.down.circle",
                    description: Text(
                        "Your downloaded files will appear here."
                    )
                )
                .listRowBackground(Color.clear)
            }

            ForEach(manager.items) { item in
                downloadRow(item)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            manager.delete(item)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func downloadRow(
        _ item: BrowserDownloadItem
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.status == .finished,
                let url = item.fileURL,
                BrowserMediaPolicy.isMediaFile(url)
            {

                NavigationLink {
                    BrowserOfflinePlayerView(
                        url: url,
                        title: item.filename
                    )
                } label: {
                    downloadInformation(item)
                }
            } else {
                downloadInformation(item)
            }

            if item.status == .downloading {
                if item.totalBytes > 0 {
                    ProgressView(value: item.fractionCompleted)

                    Text(
                        item.fractionCompleted,
                        format: .percent.precision(.fractionLength(0))
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }

                Button("Cancel download", role: .cancel) {
                    manager.cancel(item)
                }
                .font(.subheadline)
            }

            if let reason = item.failureMessage {
                Label {
                    Text(verbatim: reason)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if item.isPrivate {
                Label(
                    "Temporary private download",
                    systemImage: "hand.raised"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if item.status == .finished,
                let url = item.fileURL
            {
                ShareLink(item: url) {
                    Label("Share file", systemImage: "square.and.arrow.up")
                }
            }

            if item.status == .downloading {
                Button("Cancel download", systemImage: "xmark") {
                    manager.cancel(item)
                }
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                manager.delete(item)
            }
        }
    }

    private func downloadInformation(
        _ item: BrowserDownloadItem
    ) -> some View {
        HStack(spacing: 12) {
            Image(
                systemName: item.isPrivate
                    ? "hand.raised"
                    : item.status == .finished
                        ? "play.rectangle"
                        : "arrow.down.circle"
            )
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    item.filename.isEmpty
                        ? String(localized: "Download")
                        : item.filename
                )
                .font(.body)
                .lineLimit(2)

                Text(item.status.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private struct BrowserOfflinePlayerView: View {
        let url: URL
        let title: String

        @State private var player: AVPlayer?
        @State private var failed = false

        var body: some View {
            Group {
                if failed {
                    ContentUnavailableView(
                        "Cannot play this file",
                        systemImage: "play.slash",
                        description: Text(
                            "The file is missing or its format is not supported."
                        )
                    )
                } else if let player {
                    VideoPlayer(player: player)
                        .background(.black)
                } else {
                    ProgressView("Loading video")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share video")
                }
            }
            .task(id: url) {
                await loadVideo()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }

        @MainActor
        private func loadVideo() async {
            failed = false

            do {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    failed = true
                    return
                }

                let asset = AVURLAsset(url: url)

                guard try await asset.load(.isPlayable) else {
                    failed = true
                    return
                }

                try Task.checkCancellation()

                let newPlayer = AVPlayer(
                    playerItem: AVPlayerItem(asset: asset)
                )

                player = newPlayer
                newPlayer.play()

            } catch is CancellationError {
                // Navigation was dismissed.
            } catch {
                failed = true
            }
        }
    }

    private func startDirectDownload() {
        let input = directLink.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard let url = URL(string: input),
            BrowserMediaPolicy.isDirectURL(url)
        else {
            manager.mediaError =
                "Enter a supported direct video or audio URL."
            return
        }

        manager.startMedia(
            url,
            session: session,
            isPrivate: isPrivate
        )

        directLink = ""
    }

    private func scan() async {
        guard !session.isHome, !scanning else { return }

        scanning = true
        scanFailed = false

        defer { scanning = false }

        do {
            candidates = try await session.discoverMedia()
        } catch {
            candidates = []
            scanFailed = true
        }
    }
}

#Preview("Downloads") {
    BrowserDownloadsView(
        manager: BrowserDownloadManager(),
        session: BrowserSession(),
        isPrivate: false
    )
}

#Preview("Private Downloads") {
    BrowserDownloadsView(
        manager: BrowserDownloadManager(),
        session: BrowserSession(),
        isPrivate: true
    )
}
