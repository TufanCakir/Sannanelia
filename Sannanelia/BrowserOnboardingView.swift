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

    @State private var page = 0

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedEngine: Binding<BrowserSearchEngine> {
        Binding(
            get: {
                BrowserSearchEngine(rawValue: searchEngine) ?? .duckDuckGo
            },
            set: {
                searchEngine = $0.rawValue
            }
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max")
                Text("SANNANELIA")
                    .tracking(3)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ThemeManager.accent(scheme))
            .padding(.top, 30)

            Spacer(minLength: 12)

            Group {
                switch page {
                case 0:
                    welcomePage
                case 1:
                    searchPage
                default:
                    readyPage
                }
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == page
                                ? ThemeManager.gold(scheme)
                                : ThemeManager.accent(scheme).opacity(0.2)
                        )
                        .frame(width: index == page ? 28 : 8, height: 6)
                }
            }
            .accessibilityHidden(true)

            Button {
                if page < 2 {
                    withAnimation(
                        reduceMotion ? nil : .easeInOut(duration: 0.25)
                    ) {
                        page += 1
                    }
                } else {
                    complete()
                }
            } label: {
                HStack {
                    Spacer()
                    Text(page == 2 ? "Start browsing" : "Continue")
                    Image(systemName: page == 2 ? "checkmark" : "arrow.right")
                    Spacer()
                }
                .font(.headline)
                .padding(18)
                .foregroundStyle(ThemeManager.foreground(scheme))
                .background(
                    ThemeManager.surface(scheme),
                    in: RoundedRectangle(cornerRadius: 18)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeManager.background(scheme))
    }

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "sun.max")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(ThemeManager.gold(scheme))
                .frame(width: 150, height: 150)
                .background(
                    ThemeManager.surface(scheme),
                    in: Circle()
                )
                .accessibilityHidden(true)

            Text("Welcome to Sannanelia")
                .font(.system(.largeTitle, design: .serif))
                .multilineTextAlignment(.center)

            Text("A little sunlight. A world to discover.")
                .font(.title3)
                .foregroundStyle(ThemeManager.accent(scheme))
                .multilineTextAlignment(.center)
        }
    }

    private var searchPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(ThemeManager.gold(scheme))

            Text("Choose your search engine")
                .font(.system(.title2, design: .serif))
                .multilineTextAlignment(.center)

            Text(
                "Choose how you want to search the web. You can change this later in Settings."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(BrowserSearchEngine.allCases) { engine in
                        Button {
                            selectedEngine.wrappedValue = engine
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: engine.symbol)
                                    .font(.title3)
                                    .frame(width: 30)
                                    .foregroundStyle(ThemeManager.gold(scheme))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(engine.rawValue)
                                        .font(.headline)

                                    Text(engine.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(
                                    systemName: selectedEngine.wrappedValue
                                        == engine
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                                .foregroundStyle(ThemeManager.gold(scheme))
                            }
                            .padding(15)
                            .background(
                                ThemeManager.surface(scheme),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ThemeManager.foreground(scheme))
                        .accessibilityAddTraits(
                            selectedEngine.wrappedValue == engine
                                ? .isSelected : []
                        )
                    }
                }
            }
            .frame(maxHeight: 380)
        }
    }

    private var readyPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(ThemeManager.gold(scheme))

            Text("You're all set")
                .font(.system(.largeTitle, design: .serif))

            Text(
                "Your search engine is \(selectedEngine.wrappedValue.rawValue)."
            )
            .foregroundStyle(.secondary)

            Text("Enjoy exploring with Sannanelia.")
                .foregroundStyle(ThemeManager.accent(scheme))
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    BrowserOnboardingView(complete: {})
}
