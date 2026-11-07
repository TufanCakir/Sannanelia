import SwiftUI
import SwiftData

@main
struct SannaneliaApp: App {
    @State private var container: ModelContainer?
    @State private var storageFailed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView().modelContainer(container)
                } else if storageFailed {
                    ContentUnavailableView {
                        Label("Browser data could not be opened", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your existing data has not been deleted. Try opening it again.")
                    } actions: {
                        Button("Try again", action: openStorage)
                    }
                } else {
                    ProgressView().task { openStorage() }
                }
            }
        }
    }

    private func openStorage() {
        do {
            container = try ModelContainer(for: BrowserBookmark.self, BrowserHistoryEntry.self, PersistedBrowserTab.self, DownloadRecord.self)
            storageFailed = false
        } catch {
            storageFailed = true
        }
    }
}
