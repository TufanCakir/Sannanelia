import SwiftUI
import WebKit

struct BrowserFindView: View {
    let session: BrowserSession
    @State private var query = ""
    @State private var found: Bool?
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Find on page", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { search(backwards: false) }
                HStack {
                    Button("Previous match", systemImage: "chevron.up") { search(backwards: true) }
                    Spacer()
                    Button("Next match", systemImage: "chevron.down") { search(backwards: false) }
                }
                .disabled(query.isEmpty)
                if let found {
                    Text(found ? "Match found" : "No matches").font(.caption)
                }
            }
            .padding()
            .navigationTitle("Find on page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(240), .medium])
    }

    private func search(backwards: Bool) {
        guard !query.isEmpty else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        session.webView.find(query, configuration: configuration) { result in
            found = result.matchFound
        }
    }
}
