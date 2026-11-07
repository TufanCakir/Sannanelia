//
//  BrowserSettingsView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI
import WebKit

struct BrowserSettingsView: View {
    let data: BrowserDataService
    let manager: BrowserTabManager
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("language") private var language = "system"
    @AppStorage("searchEngine") private var searchEngine = BrowserSearchEngine
        .duckDuckGo.rawValue
    @AppStorage("restoreTabs") private var restoreTabs = true
    @AppStorage("javaScript") private var javaScript = true
    @AppStorage("desktopDefault") private var desktopDefault = false
    @AppStorage("homepage") private var homepage = ""
    @State private var deletion: DataDeletion?
    @Environment(\.dismiss) private var dismiss

    private enum DataDeletion: String, Identifiable {
        case history, cookies, cache, websites
        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .history: "Clear history"
            case .cookies: "Clear cookies"
            case .cache: "Clear cache"
            case .websites: "Clear website data"
            }
        }

        var types: Set<String> {
            switch self {
            case .history: []
            case .cookies: [WKWebsiteDataTypeCookies]
            case .cache:
                [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            case .websites: WKWebsiteDataStore.allWebsiteDataTypes()
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }
                Section("Language") {
                    Picker("Language", selection: $language) {
                        Text("System").tag("system")
                        Text(verbatim: "Deutsch").tag("de")
                        Text(verbatim: "English").tag("en")
                    }
                }
                Section("Search engine") {
                    Picker("Search engine", selection: $searchEngine) {
                        ForEach(BrowserSearchEngine.allCases) { engine in
                            Text(verbatim: engine.rawValue).tag(engine.rawValue)
                        }
                    }
                }
                Section {
                    Toggle("Restore normal tabs", isOn: $restoreTabs)
                        .onChange(of: restoreTabs) { manager.persist() }
                    Toggle("Desktop mode for new tabs", isOn: $desktopDefault)
                    TextField("Homepage address (optional)", text: $homepage)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Browser")
                } footer: {
                    Text(
                        "Leave the address empty to use the Sannanelia start page."
                    )
                }
                Section {
                    Toggle("JavaScript", isOn: $javaScript)
                    Button("Clear history", role: .destructive) {
                        deletion = .history
                    }
                    Button("Clear cookies", role: .destructive) {
                        deletion = .cookies
                    }
                    Button("Clear cache", role: .destructive) {
                        deletion = .cache
                    }
                    Button("Clear website data", role: .destructive) {
                        deletion = .websites
                    }
                    if data.isClearing { ProgressView("Clearing website data") }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(
                        "JavaScript changes apply on the next page load. Website data and browsing history are deleted separately. Open pages can create new website data."
                    )
                }
                .disabled(data.isClearing)
                Section("About Sannanelia") {
                    LabeledContent(
                        "Version",
                        value: Bundle.main.infoDictionary?[
                            "CFBundleShortVersionString"
                        ] as? String ?? "1.0"
                    )
                    Text(
                        "Websites and your selected search engine receive requests only when you navigate. Website cookies are stored by WebKit on this device."
                    )
                    Text(
                        "Private tabs do not save browsing history. Websites and your internet provider can still see your activity."
                    )
                    Text(
                        "Built with Apple frameworks. No third-party dependencies."
                    )
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete selected browser data?",
                isPresented: Binding(
                    get: { deletion != nil },
                    set: { if !$0 { deletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: deletion
            ) { action in
                Button(role: .destructive) {
                    deletion = nil
                    if action == .history {
                        data.clearHistory()
                    } else {
                        manager.tabs.forEach {
                            $0.session?.webView.stopLoading()
                        }
                        Task { await data.clearWebsiteData(action.types) }
                    }
                } label: {
                    Text(action.title)
                }
                Button("Cancel", role: .cancel) { deletion = nil }
            } message: { action in
                if action == .history {
                    Text(
                        "This removes your visit list. Cookies and website data are kept."
                    )
                } else {
                    Text(
                        "This affects normal browsing only. Removing cookies or website data may sign you out. Bookmarks and history are kept."
                    )
                }
            }
        }
    }
}
