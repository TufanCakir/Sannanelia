//
//  BrowserHTMLSourceView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI
import UIKit

struct BrowserHTMLSourceView: View {
    let session: BrowserSession

    @Environment(\.colorScheme) private var scheme

    @State private var html = ""
    @State private var lines: [String] = []
    @State private var searchText = ""
    @State private var showsSearch = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var wrapsLines = true
    @State private var showsLineNumbers = true
    @State private var viewerMode: ViewerMode = .source
    @State private var domNodes: [HTMLNode] = []
    @State private var domError: String?
    @State private var isLoadingDOM = false

    private enum ViewerMode: String, CaseIterable {
        case source = "Source"
        case tree = "DOM Tree"
        case console = "Console"
    }

    private var foreground: Color {
        ThemeManager.foreground(scheme)
    }

    private var accent: Color {
        ThemeManager.accent(scheme)
    }

    private var displayedLines: [Int] {
        guard !searchText.isEmpty else {
            return Array(lines.indices)
        }

        return lines.indices.filter {
            lines[$0].localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading HTML...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to load HTML",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )

            } else if html.isEmpty {
                ContentUnavailableView(
                    "No HTML available",
                    systemImage: "doc.text"
                )

            } else {
                sourceContent
            }
        }
        .background(ThemeManager.background(scheme))
        .navigationTitle("HTML Source")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsSearch.toggle()
                    if !showsSearch {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                Menu {
                    Button("Reload", systemImage: "arrow.clockwise") {
                        Task { await loadHTML() }
                    }

                    Button(
                        wrapsLines ? "Disable Line Wrap" : "Enable Line Wrap",
                        systemImage: "text.alignleft"
                    ) {
                        wrapsLines.toggle()
                    }

                    Button(
                        showsLineNumbers
                            ? "Hide Line Numbers" : "Show Line Numbers",
                        systemImage: "list.number"
                    ) {
                        showsLineNumbers.toggle()
                    }

                    Button("Copy All", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = html
                    }

                    ShareLink(item: html) {
                        Label("Share HTML", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadHTML()
        }
    }

    private var sourceContent: some View {
        VStack(spacing: 0) {
            Picker("View Mode", selection: $viewerMode) {
                Text("Source").tag(ViewerMode.source)
                Text("DOM Tree").tag(ViewerMode.tree)
                Text("Console").tag(ViewerMode.console)
            }
            .pickerStyle(.segmented)
            .padding()

            switch viewerMode {
            case .source:
                sourceViewer

            case .tree:
                domTreeViewer

            case .console:
                BrowserConsoleView(session: session)
            }
        }
        .onChange(of: viewerMode) { _, newMode in
            if newMode == .tree && domNodes.isEmpty {
                Task { await loadDOM() }
            }
        }
    }

    private var sourceViewer: some View {
        VStack(spacing: 0) {
            if showsSearch {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(accent)

                    TextField("Search HTML", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                }
                .padding(12)
                .background(ThemeManager.surface(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }

            HStack {
                Label(
                    "\(lines.count) lines",
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )

                Spacer()

                if !searchText.isEmpty {
                    Text("\(displayedLines.count) matches")
                }
            }
            .font(.caption)
            .foregroundStyle(accent)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView(
                wrapsLines ? [.vertical] : [.vertical, .horizontal]
            ) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(displayedLines, id: \.self) { index in
                        sourceLine(
                            lines[index],
                            number: index + 1
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .frame(
                    maxWidth: wrapsLines ? .infinity : nil,
                    alignment: .leading
                )
            }
            .defaultScrollAnchor(.top)
        }
    }

    private var domTreeViewer: some View {
        Group {
            if isLoadingDOM {
                ProgressView("Reading DOM...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let domError {
                ContentUnavailableView(
                    "DOM unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(domError)
                )

            } else if domNodes.isEmpty {
                ContentUnavailableView(
                    "No DOM elements",
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )

            } else {
                List {
                    OutlineGroup(
                        domNodes,
                        children: \.children
                    ) { node in
                        Text(verbatim: node.displayName)
                            .font(
                                .system(
                                    .caption,
                                    design: .monospaced
                                )
                            )
                            .foregroundStyle(
                                ThemeManager.foreground(scheme)
                            )
                            .textSelection(.enabled)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(ThemeManager.background(scheme))
    }

    @MainActor
    private func loadDOM() async {
        guard !isLoadingDOM else { return }

        isLoadingDOM = true
        domError = nil

        defer { isLoadingDOM = false }

        do {
            domNodes = try await session.getDOMTree()
        } catch {
            domNodes = []
            domError = error.localizedDescription
        }
    }

    private func sourceLine(
        _ line: String,
        number: Int
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if showsLineNumbers {
                Text(number.formatted())
                    .foregroundStyle(accent.opacity(0.8))
                    .frame(width: 42, alignment: .trailing)
                    .textSelection(.disabled)
            }

            highlightedHTML(line)
                .frame(
                    maxWidth: wrapsLines ? .infinity : nil,
                    alignment: .leading
                )
                .fixedSize(
                    horizontal: !wrapsLines,
                    vertical: true
                )
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
    }

    private func highlightedHTML(_ line: String) -> Text {
        let pattern =
            #"<!--.*?-->|</?[A-Za-z][A-Za-z0-9:-]*|[A-Za-z_:][A-Za-z0-9_:.-]*(?=\s*=)|"[^"]*"|'[^']*'|/?>"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(verbatim: line)
                .foregroundColor(foreground)
        }

        let nsLine = line as NSString
        let matches = regex.matches(
            in: line,
            range: NSRange(location: 0, length: nsLine.length)
        )

        var result = Text("")
        var location = 0

        for match in matches {
            let range = match.range

            if range.location > location {
                let plain = nsLine.substring(
                    with: NSRange(
                        location: location,
                        length: range.location - location
                    )
                )

                result =
                    result
                    + Text(verbatim: plain)
                    .foregroundColor(foreground)
            }

            let token = nsLine.substring(with: range)
            let color: Color

            if token.hasPrefix("<!--") {
                color = accent
            } else if token.hasPrefix("<") || token == ">" || token == "/>" {
                color =
                    scheme == .dark
                    ? .cyan : .blue
            } else if token.hasPrefix("\"") || token.hasPrefix("'") {
                color =
                    scheme == .dark
                    ? .green : Color(red: 0.12, green: 0.45, blue: 0.20)
            } else {
                color =
                    scheme == .dark
                    ? .orange : .purple
            }

            result =
                result
                + Text(verbatim: token)
                .foregroundColor(color)

            location = NSMaxRange(range)
        }

        if location < nsLine.length {
            result =
                result
                + Text(
                    verbatim: nsLine.substring(from: location)
                )
                .foregroundColor(foreground)
        }

        return result
    }

    @MainActor
    private func loadHTML() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let source = try await session.getHTMLSource()

            html = source
            lines = formatHTML(source)
                .components(separatedBy: "\n")

        } catch {
            html = ""
            lines = []
            errorMessage = error.localizedDescription
        }
    }

    private func formatHTML(_ source: String) -> String {
        // Preserve existing line breaks.
        // Only separate directly adjacent tags.
        source.replacingOccurrences(
            of: "><",
            with: ">\n<"
        )
    }
}
