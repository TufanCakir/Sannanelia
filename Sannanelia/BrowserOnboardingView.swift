//
//  BrowserOnboardingView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI

struct BrowserOnboardingView: View {
    let complete: () -> Void

    @AppStorage("searchEngine")
    private var searchEngine = BrowserSearchEngine.duckDuckGo.rawValue

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0

    private let pageCount = 3

    private var selectedEngine: BrowserSearchEngine {
        BrowserSearchEngine(rawValue: searchEngine) ?? .duckDuckGo
    }

    private var isLastPage: Bool {
        page == pageCount - 1
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 600

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    searchPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, compact ? 20 : 40)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ThemeManager.background(scheme))
        .foregroundStyle(ThemeManager.foreground(scheme))
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        pageContainer {
            VStack(spacing: 22) {
                Image(
                    systemName: BrowserAppearance.symbol(
                        scheme,
                        light: "sun.max",
                        dark: "moon"
                    )
                )
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 68, weight: .ultraLight))
                .foregroundStyle(ThemeManager.gold(scheme))
                .frame(width: 140, height: 140)
                .background(
                    ThemeManager.surface(scheme),
                    in: Circle()
                )
                .accessibilityHidden(true)

                Text("Welcome to Sannanelia")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("A little sunlight. A world to discover.")
                    .font(.title3)
                    .foregroundStyle(ThemeManager.accent(scheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Search Engine

    private var searchPage: some View {
        pageContainer {
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(ThemeManager.gold(scheme))
                    .accessibilityHidden(true)

                Text("Choose your search engine")
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(
                    "Choose how you want to search the web. You can change this later in Settings."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    ForEach(BrowserSearchEngine.allCases) { engine in
                        searchEngineRow(engine)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func searchEngineRow(
        _ engine: BrowserSearchEngine
    ) -> some View {
        let isSelected = selectedEngine == engine

        return Button {
            searchEngine = engine.rawValue
        } label: {
            HStack(spacing: 14) {
                Image(systemName: engine.symbol)
                    .font(.title3)
                    .frame(width: 30)
                    .foregroundStyle(ThemeManager.gold(scheme))

                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.rawValue)
                        .font(.headline)

                    Text(engine.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    isSelected
                        ? ThemeManager.gold(scheme)
                        : .secondary
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                ThemeManager.surface(scheme),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        ThemeManager.gold(scheme)
                            .opacity(isSelected ? 0.65 : 0),
                        lineWidth: 1.5
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Ready

    private var readyPage: some View {
        pageContainer {
            VStack(spacing: 22) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(ThemeManager.gold(scheme))
                    .accessibilityHidden(true)

                Text("You're all set")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.semibold)

                Text(
                    "Your search engine is \(selectedEngine.rawValue)."
                )
                .foregroundStyle(.secondary)

                Text("Enjoy exploring with Sannanelia.")
                    .foregroundStyle(ThemeManager.accent(scheme))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Page Container

    private func pageContainer<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { geometry in
            ScrollView {
                content()
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometry.size.height
                    )
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 20) {
            pageIndicator

            HStack(spacing: 12) {
                if page > 0 {
                    Button {
                        changePage(to: page - 1)
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    if isLastPage {
                        complete()
                    } else {
                        changePage(to: page + 1)
                    }
                } label: {
                    Label(
                        isLastPage
                            ? String(localized: "Start browsing")
                            : String(localized: "Continue"),
                        systemImage: isLastPage
                            ? "checkmark"
                            : "arrow.right"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(ThemeManager.gold(scheme))
            }
            .font(.headline)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(
                        index == page
                            ? ThemeManager.gold(scheme)
                            : ThemeManager.accent(scheme).opacity(0.2)
                    )
                    .frame(
                        width: index == page ? 28 : 8,
                        height: 6
                    )
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: page
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("Page \(page + 1) of \(pageCount)")
        )
    }

    // MARK: - Navigation

    private func changePage(to newPage: Int) {
        guard (0..<pageCount).contains(newPage) else {
            return
        }

        if reduceMotion {
            page = newPage
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                page = newPage
            }
        }
    }
}

#Preview {
    BrowserOnboardingView(complete: {})
}
