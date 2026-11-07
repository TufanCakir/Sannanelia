import Foundation

enum BrowserSearchEngine: String, CaseIterable, Identifiable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"
    case brave = "Brave Search"
    case ecosia = "Ecosia"

    var id: String { rawValue }

    var endpoint: String {
        switch self {
        case .duckDuckGo: "https://duckduckgo.com/"
        case .google: "https://www.google.com/search"
        case .bing: "https://www.bing.com/search"
        case .brave: "https://search.brave.com/search"
        case .ecosia: "https://www.ecosia.org/search"
        }
    }
}

enum BrowserSearchService {
    /// Input remains local until the person submits it.
    static func destination(for input: String, engine: BrowserSearchEngine) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let hasWhitespace = text.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
        if text.lowercased().hasPrefix("https://") || text.lowercased().hasPrefix("http://") {
            guard let url = URL(string: text), let host = url.host, !host.isEmpty,
                  url.user == nil, url.password == nil, !hasWhitespace else { return nil }
            return url
        }
        // Never execute pasted javascript:, data:, file:, or arbitrary app schemes.
        if text.contains("://") || text.lowercased().hasPrefix("javascript:")
            || text.lowercased().hasPrefix("data:") || text.lowercased().hasPrefix("file:") {
            return nil
        }
        if !hasWhitespace, text.contains(".") || text.hasPrefix("localhost") || text.hasPrefix("[") {
            if let url = URL(string: "https://" + text), let host = url.host, !host.isEmpty,
               url.user == nil, url.password == nil {
                return url
            }
        }
        var components = URLComponents(string: engine.endpoint)
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        // Form-style search endpoints interpret a literal plus as a space.
        let encodedQuery = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components?.percentEncodedQuery = encodedQuery
        return components?.url
    }
}
