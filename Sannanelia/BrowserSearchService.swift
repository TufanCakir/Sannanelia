//
//  BrowserSearchService.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation

enum BrowserSearchEngine: String, CaseIterable, Identifiable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"
    case brave = "Brave Search"
    case ecosia = "Ecosia"
    case startpage = "Startpage"
    case qwant = "Qwant"
    case mojeek = "Mojeek"
    case kagi = "Kagi"
    case yahoo = "Yahoo"

    var id: String { rawValue }

    var endpoint: String {
        switch self {
        case .duckDuckGo: "https://duckduckgo.com/"
        case .google: "https://www.google.com/search"
        case .bing: "https://www.bing.com/search"
        case .brave: "https://search.brave.com/search"
        case .ecosia: "https://www.ecosia.org/search"
        case .startpage: "https://www.startpage.com/sp/search"
        case .qwant: "https://www.qwant.com/"
        case .mojeek: "https://www.mojeek.com/search"
        case .kagi: "https://kagi.com/search"
        case .yahoo: "https://search.yahoo.com/search"
        }
    }

    var queryParameter: String {
        switch self {
        case .startpage: "query"
        case .yahoo: "p"
        default: "q"
        }
    }

    var symbol: String {
        switch self {
        case .duckDuckGo: "hand.raised"
        case .google: "g.circle"
        case .bing: "b.circle"
        case .brave: "shield"
        case .ecosia: "leaf"
        case .startpage: "lock.shield"
        case .qwant: "magnifyingglass"
        case .mojeek: "globe"
        case .kagi: "sparkle.magnifyingglass"
        case .yahoo: "y.circle"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .duckDuckGo: "Privacy-focused search"
        case .google: "Search the web with Google"
        case .bing: "Microsoft's search engine"
        case .brave: "Independent, privacy-focused search"
        case .ecosia: "Search supporting climate projects"
        case .startpage: "Private search with Google results"
        case .qwant: "European search engine"
        case .mojeek: "Independent search index"
        case .kagi: "Premium search, account required"
        case .yahoo: "Search the web with Yahoo"
        }
    }
}

enum BrowserSearchService {
    /// Converts a typed address or search phrase into a safe web destination.
    /// No network request is made until the caller loads the returned URL.
    static func destination(for input: String, engine: BrowserSearchEngine)
        -> URL?
    {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let lower = text.lowercased()
        let containsWhitespace =
            text.rangeOfCharacter(from: .whitespacesAndNewlines) != nil

        // Only HTTP(S) links are navigable; block embedded credentials.
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") {
            guard !containsWhitespace,
                let components = URLComponents(string: text),
                let scheme = components.scheme?.lowercased(),
                ["http", "https"].contains(scheme),
                let host = components.host, !host.isEmpty,
                components.user == nil, components.password == nil,
                let url = components.url
            else { return nil }
            return url
        }

        // Reject any other explicit scheme, including javascript:, data:, file:,
        // mailto:, and custom application schemes.
        if hasExplicitScheme(text) { return nil }

        // Avoid interpreting phrases with spaces as web addresses.
        if !containsWhitespace, looksLikeWebAddress(text) {
            if let components = URLComponents(string: "https://" + text),
                let host = components.host, !host.isEmpty,
                components.user == nil, components.password == nil,
                let url = components.url
            {
                return url
            }
        }

        // Treat everything else as a search query. URLComponents performs
        // percent encoding for Unicode, punctuation, and whitespace.
        guard var components = URLComponents(string: engine.endpoint) else {
            return nil
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: engine.queryParameter, value: text))
        components.queryItems = items
        // Search endpoints decode a literal plus as a space; preserve the input.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    private static func hasExplicitScheme(_ text: String) -> Bool {
        guard let colon = text.firstIndex(of: ":") else { return false }
        let prefix = text[..<colon]
        guard let first = prefix.first, first.isASCII, first.isLetter else {
            return false
        }
        return prefix.dropFirst().allSatisfy {
            $0.isASCII
                && ($0.isLetter || $0.isNumber || $0 == "+" || $0 == "-"
                    || $0 == ".")
        }
    }

    private static func looksLikeWebAddress(_ text: String) -> Bool {
        let hostPart = String(
            text.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        )
        guard !hostPart.isEmpty, !hostPart.contains("@") else { return false }
        let host = String(
            hostPart.split(separator: ":", maxSplits: 1).first ?? ""
        )
        let lower = host.lowercased()
        if lower == "localhost" { return true }
        if hostPart.hasPrefix("[") && hostPart.contains("]") { return true }
        // Dotted names, including IPv4 addresses and IDNs, can be addresses.
        return host.contains(".") && !host.hasPrefix(".")
            && !host.hasSuffix(".")
    }
}
