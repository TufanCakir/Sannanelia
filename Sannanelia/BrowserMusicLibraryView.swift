//
//  BrowserMusicLibraryView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 08.11.26.
//

import AVFoundation
import SwiftData
import SwiftUI

struct BrowserMusicLibraryView: View {
    let manager: BrowserDownloadManager

    @Environment(\.modelContext) private var context

    @Query(sort: \BrowserMusicPlaylist.createdAt, order: .reverse)
    private var playlists: [BrowserMusicPlaylist]

    @State private var searchText = ""
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""

    @State private var player = AVPlayer()
    @State private var currentTrackID: UUID?
    @State private var isPlaying = false

    private let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aiff",
        "caf", "flac", "mp4", "mov",
    ]

    private var tracks: [BrowserDownloadItem] {
        manager.items.filter { item in
            guard item.status == .finished,
                !item.isPrivate,
                let url = item.fileURL,
                audioExtensions.contains(url.pathExtension.lowercased())
            else {
                return false
            }

            return searchText.isEmpty
                || item.filename.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        List {
            Section("Playlists") {
                Button {
                    showingNewPlaylist = true
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }

                ForEach(playlists) { playlist in
                    NavigationLink {
                        playlistDetail(playlist)
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                Text("\(playlist.trackIDs.count) tracks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.note.list")
                        }
                    }
                }
                .onDelete(perform: deletePlaylists)
            }

            Section("Downloaded Music") {
                if tracks.isEmpty {
                    ContentUnavailableView(
                        "No Music",
                        systemImage: "music.note",
                        description: Text(
                            "Downloaded audio and video files will appear here."
                        )
                    )
                } else {
                    ForEach(tracks) { item in
                        trackRow(item)
                    }
                }
            }
        }
        .navigationTitle("Music")
        .searchable(text: $searchText, prompt: "Search Music")
        .safeAreaInset(edge: .bottom) {
            if let currentTrackID,
                let item = manager.items.first(where: {
                    $0.id == currentTrackID
                })
            {
                miniPlayer(item)
            }
        }
        .alert("New Playlist", isPresented: $showingNewPlaylist) {
            TextField("Playlist Name", text: $newPlaylistName)

            Button("Create") {
                createPlaylist()
            }

            Button("Cancel", role: .cancel) {
                newPlaylistName = ""
            }
        }
        .onDisappear {
            player.pause()
            isPlaying = false
        }
    }

    private func trackRow(
        _ item: BrowserDownloadItem
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                play(item)
            } label: {
                Label {
                    Text(item.filename)
                        .lineLimit(2)
                } icon: {
                    Image(
                        systemName: currentTrackID == item.id
                            && isPlaying
                            ? "speaker.wave.2.fill"
                            : "music.note"
                    )
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                ForEach(playlists) { playlist in
                    Button {
                        playlist.add(item.id)
                        try? context.save()
                    } label: {
                        Label(
                            playlist.name,
                            systemImage: playlist.contains(item.id)
                                ? "checkmark"
                                : "plus"
                        )
                    }
                    .disabled(playlist.contains(item.id))
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .disabled(playlists.isEmpty)
            .accessibilityLabel("Add to Playlist")
        }
    }

    private func playlistDetail(
        _ playlist: BrowserMusicPlaylist
    ) -> some View {
        List {
            let savedTracks = playlist.trackIDs.compactMap { id in
                manager.items.first {
                    $0.id == id && $0.status == .finished && !$0.isPrivate
                }
            }

            if savedTracks.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "music.note.list",
                    description: Text("Add music from your library.")
                )
            }

            ForEach(savedTracks) { item in
                Button {
                    play(item)
                } label: {
                    Label(
                        item.filename,
                        systemImage: "play.circle"
                    )
                }
                .swipeActions {
                    Button("Remove", role: .destructive) {
                        playlist.remove(item.id)
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
    }

    private func miniPlayer(
        _ item: BrowserDownloadItem
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.title2)
                .frame(width: 36)

            Text(item.filename)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Button {
                togglePlayback()
            } label: {
                Image(
                    systemName: isPlaying
                        ? "pause.fill"
                        : "play.fill"
                )
                .font(.title3)
                .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func play(_ item: BrowserDownloadItem) {
        guard let url = item.fileURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            return
        }

        player.replaceCurrentItem(
            with: AVPlayerItem(url: url)
        )

        currentTrackID = item.id
        player.play()
        isPlaying = true
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }

        isPlaying.toggle()
    }

    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !name.isEmpty else { return }

        context.insert(BrowserMusicPlaylist(name: name))
        try? context.save()
        newPlaylistName = ""
    }

    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            context.delete(playlists[index])
        }

        try? context.save()
    }
}
