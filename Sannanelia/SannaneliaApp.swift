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
    @State private var storageError: String?
    @State private var isOpeningStorage = false

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            appContent
                .task {
                    if container == nil && storageError == nil {
                        openStorage()
                    }
                }
        }
    }

    @ViewBuilder
    private var appContent: some View {
        if let container {
            browserContent
                .modelContainer(container)
        } else if let storageError {
            storageErrorView(storageError)
        } else {
            ProgressView("Preparing Sannanelia…")
        }
    }

    @ViewBuilder
    private var browserContent: some View {
        if hasCompletedOnboarding {
            ContentView()
        } else {
            BrowserOnboardingView {
                withAnimation(.easeInOut(duration: 0.25)) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }

    private func storageErrorView(_ message: String) -> some View {
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
            .buttonStyle(.borderedProminent)
            .disabled(isOpeningStorage)
        }
        .accessibilityHint(Text(message))
    }

    @MainActor
    private func openStorage() {
        guard container == nil, !isOpeningStorage else {
            return
        }

        isOpeningStorage = true
        storageError = nil

        defer {
            isOpeningStorage = false
        }

        do {
            let schema = Schema([
                BrowserBookmark.self,
                BrowserHistoryEntry.self,
                PersistedBrowserTab.self,
            ])

            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            storageError = error.localizedDescription

            #if DEBUG
                print("Sannanelia SwiftData error: \(error)")
            #endif
        }
    }
}
