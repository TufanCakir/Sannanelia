//
//  BrowserJavaScriptView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI
import UIKit

struct BrowserJavaScriptView: View {

    let session: BrowserSession

    @Environment(\.colorScheme) private var scheme

    @State private var script = "document.title"
    @State private var output = ""
    @State private var isRunning = false
    @State private var hasError = false
    @State private var executionTime: Double?

    @FocusState private var editorFocused: Bool

    private let defaultScript = "document.title"

    private var canRun: Bool {
        !isRunning
            && !session.isHome
            && !script.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
    }

    var body: some View {
        Form {

            // MARK: - JavaScript Editor

            Section {
                TextEditor(text: $script)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($editorFocused)
                    .accessibilityLabel("JavaScript Editor")

            } header: {
                HStack {
                    Label(
                        "JavaScript Editor",
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    )

                    Spacer()

                    Text("\(script.count) characters")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Execution

            Section {
                Button {
                    Task {
                        await runScript()
                    }
                } label: {
                    HStack {
                        Label(
                            "Run JavaScript",
                            systemImage: "play.fill"
                        )

                        Spacer()

                        if isRunning {
                            ProgressView()
                        }
                    }
                }
                .disabled(!canRun)

                Button {
                    editorFocused = false
                } label: {
                    Label(
                        "Dismiss Keyboard",
                        systemImage: "keyboard.chevron.compact.down"
                    )
                }
                .disabled(!editorFocused)

            } footer: {
                Text(
                    "JavaScript runs in the currently loaded webpage."
                )
            }

            // MARK: - Result

            Section {
                if output.isEmpty {
                    ContentUnavailableView(
                        "No Result",
                        systemImage: "terminal",
                        description: Text(
                            "Run JavaScript to see its result."
                        )
                    )
                    .frame(maxWidth: .infinity)

                } else {
                    VStack(alignment: .leading, spacing: 12) {

                        HStack {
                            Label(
                                hasError ? "Error" : "Success",
                                systemImage: hasError
                                    ? "xmark.circle.fill"
                                    : "checkmark.circle.fill"
                            )
                            .foregroundStyle(
                                hasError ? .red : .green
                            )

                            Spacer()

                            if let executionTime {
                                Text(
                                    executionTime,
                                    format: .number.precision(
                                        .fractionLength(2)
                                    )
                                )
                                .monospacedDigit()

                                Text("ms")
                            }
                        }
                        .font(.caption)

                        Divider()

                        Text(verbatim: output)
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

                        Button {
                            UIPasteboard.general.string = output
                        } label: {
                            Label(
                                "Copy Result",
                                systemImage: "doc.on.doc"
                            )
                        }
                    }
                }

            } header: {
                Label(
                    "Output",
                    systemImage: "terminal"
                )
            }

            // MARK: - Tools

            Section("Tools") {

                Menu {
                    Button(
                        "Page Title",
                        systemImage: "textformat"
                    ) {
                        script = "document.title"
                    }

                    Button(
                        "Current URL",
                        systemImage: "link"
                    ) {
                        script = "window.location.href"
                    }

                    Button(
                        "HTML Source",
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    ) {
                        script = "document.documentElement.outerHTML"
                    }

                    Button(
                        "Page Background",
                        systemImage: "paintpalette"
                    ) {
                        script = """
                            document.body.style.backgroundColor = "red";
                            """
                    }

                    Button(
                        "Console Log",
                        systemImage: "terminal"
                    ) {
                        script = """
                            console.log("Hello Sannanelia!");
                            """
                    }

                    Button(
                        "Count Links",
                        systemImage: "number"
                    ) {
                        script = """
                            document.querySelectorAll("a").length
                            """
                    }

                } label: {
                    Label(
                        "JavaScript Examples",
                        systemImage: "curlybraces"
                    )
                }

                Button {
                    UIPasteboard.general.string = script
                } label: {
                    Label(
                        "Copy Script",
                        systemImage: "doc.on.doc"
                    )
                }

                Button {
                    script = UIPasteboard.general.string ?? script
                } label: {
                    Label(
                        "Paste Script",
                        systemImage: "doc.on.clipboard"
                    )
                }

                Button(role: .destructive) {
                    script = defaultScript
                    output = ""
                    hasError = false
                    executionTime = nil
                } label: {
                    Label(
                        "Reset Editor",
                        systemImage: "arrow.counterclockwise"
                    )
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("JavaScript")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await runScript()
                    }
                } label: {
                    Image(systemName: "play.fill")
                }
                .disabled(!canRun)
            }
        }
    }

    // MARK: - Execute JavaScript

    @MainActor
    private func runScript() async {
        guard canRun else { return }

        isRunning = true
        hasError = false
        output = ""
        executionTime = nil
        editorFocused = false

        let start = ContinuousClock.now

        defer {
            isRunning = false
            let duration = start.duration(to: .now)
            executionTime =
                Double(duration.components.seconds) * 1000
                + Double(duration.components.attoseconds) / 1e15
        }

        do {
            let result = try await session.executeJavaScript(script)

            if let result {
                output = String(describing: result)
            } else {
                output = "undefined"
            }

        } catch {
            hasError = true
            output = error.localizedDescription
        }
    }
}
