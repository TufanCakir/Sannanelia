//
//  SannaneliaApp.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftData
import SwiftUI

@main
struct SannaneliaApp: App {
    @State private var container: ModelContainer?
    @State private var storageFailed = false

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    Group {
                        if hasCompletedOnboarding {
                            ContentView()
                        } else {
                            BrowserOnboardingView {
                                hasCompletedOnboarding = true
                            }
                        }
                    }
                    .modelContainer(container)

                } else if storageFailed {
                    ContentUnavailableView {
                        Label(
                            "Browser data could not be opened",
                            systemImage: "externaldrive.badge.exclamationmark"
                        )
                    } description: {
                        Text(
                            "Your existing data has not been deleted. Try opening it again."
                        )
                    } actions: {
                        Button("Try again") {
                            openStorage()
                        }
                    }

                } else {
                    ProgressView("Preparing Sannanelia…")
                        .task {
                            openStorage()
                        }
                }
            }
        }
    }

    @MainActor
    private func openStorage() {
        guard container == nil else { return }

        storageFailed = false

        do {
            container = try ModelContainer(
                for:
                    BrowserBookmark.self,
                BrowserHistoryEntry.self,
                PersistedBrowserTab.self,
                DownloadRecord.self,
                BrowserMusicPlaylist.self
            )
        } catch {
            storageFailed = true
            print("SwiftData error: \(error.localizedDescription)")
        }
    }
}
