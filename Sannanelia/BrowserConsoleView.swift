//
//  BrowserConsoleView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI

struct BrowserConsoleView: View {

    let session: BrowserSession

    @Environment(\.colorScheme) private var scheme

    @State private var script = ""
    @State private var isRunning = false

    @FocusState private var inputFocused: Bool

    private var consoleStore: BrowserConsoleStore {
        session.consoleStore
    }

    private var canRun: Bool {
        !isRunning
            && !session.isHome
            && !script.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header

            HStack {
                Label(
                    "JavaScript Console",
                    systemImage: "terminal"
                )
                .font(.caption.weight(.semibold))

                Spacer()

                Text("\(consoleStore.messages.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    consoleStore.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(consoleStore.messages.isEmpty)
                .accessibilityLabel("Clear Console")
            }
            .padding()

            Divider()

            // MARK: - Messages

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        if consoleStore.messages.isEmpty {
                            ContentUnavailableView(
                                "Console Empty",
                                systemImage: "terminal",
                                description: Text(
                                    "JavaScript messages will appear here."
                                )
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(consoleStore.messages) { message in
                                consoleRow(message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(
                    of: consoleStore.messages.last?.id
                ) { _, newID in
                    guard let newID else { return }

                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(
                            newID,
                            anchor: .bottom
                        )
                    }
                }
            }

            Divider()

            // MARK: - Input

            HStack(alignment: .bottom, spacing: 12) {
                TextField(
                    "Enter JavaScript...",
                    text: $script,
                    axis: .vertical
                )
                .lineLimit(1...6)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($inputFocused)
                .onSubmit {
                    Task {
                        await execute()
                    }
                }

                Button {
                    Task {
                        await execute()
                    }
                } label: {
                    if isRunning {
                        ProgressView()
                    } else {
                        Image(systemName: "play.fill")
                            .font(.title3)
                    }
                }
                .disabled(!canRun)
                .accessibilityLabel("Run JavaScript")
            }
            .padding()
            .background(ThemeManager.surface(scheme))
        }
        .background(ThemeManager.background(scheme))
        .navigationTitle("Console")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Console Row

    private func consoleRow(
        _ message: BrowserConsoleMessage
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {

            Image(
                systemName: iconName(for: message.level)
            )
            .foregroundStyle(
                color(for: message.level)
            )
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {

                HStack {
                    Text(message.level.rawValue.uppercased())
                        .font(.caption2.weight(.semibold))

                    Spacer()

                    Text(
                        message.date,
                        format: .dateTime
                            .hour()
                            .minute()
                            .second()
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Text(verbatim: message.text)
                    .font(
                        .system(
                            .footnote,
                            design: .monospaced
                        )
                    )
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
    }

    // MARK: - Appearance

    private func iconName(
        for level: BrowserConsoleLevel
    ) -> String {
        switch level {
        case .command:
            "chevron.right"
        case .result:
            "arrow.turn.down.right"
        case .log:
            "text.bubble"
        case .info:
            "info.circle"
        case .warn:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.circle.fill"
        case .debug:
            "ladybug"
        }
    }

    private func color(
        for level: BrowserConsoleLevel
    ) -> Color {
        switch level {
        case .command:
            ThemeManager.accent(scheme)
        case .result:
            .green
        case .log:
            ThemeManager.foreground(scheme)
        case .info:
            .blue
        case .warn:
            .orange
        case .error:
            .red
        case .debug:
            .purple
        }
    }

    // MARK: - Execute JavaScript

    @MainActor
    private func execute() async {
        guard canRun else { return }

        let command = script.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        isRunning = true
        script = ""

        consoleStore.append(
            level: .command,
            text: command
        )

        defer {
            isRunning = false
        }

        do {
            let result = try await session.executeJavaScript(command)

            consoleStore.append(
                level: .result,
                text: result.map {
                    String(describing: $0)
                } ?? "undefined"
            )
        } catch {
            consoleStore.append(
                level: .error,
                text: error.localizedDescription
            )
        }
    }
}
