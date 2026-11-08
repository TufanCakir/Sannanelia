//
//  BrowserMedia.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation
import WebKit

struct BrowserMediaCandidate: Identifiable {
    let url: URL
    let title: String
    var id: String { url.absoluteString }
}

enum BrowserMediaPolicy {
    static let extensions: Set<String> = [
        "mp4", "m4v", "mov", "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf",
        "flac", "ogg", "oga", "webm",
    ]
    static let streamExtensions: Set<String> = ["m3u8", "m3u", "mpd"]

    static func isDirectURL(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "")
            && url.host != nil && url.user == nil && url.password == nil
            && !streamExtensions.contains(url.pathExtension.lowercased())
    }

    static func accepts(mimeType: String?, filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        guard !streamExtensions.contains(ext) else { return false }
        let mime =
            mimeType?.lowercased().split(separator: ";").first.map(String.init)
            ?? ""
        if mime.contains("mpegurl") || mime.contains("dash+xml") {
            return false
        }
        if mime.hasPrefix("video/") || mime.hasPrefix("audio/") { return true }
        return (mime.isEmpty || mime == "application/octet-stream")
            && extensions.contains(ext)
    }

    static func isMediaFile(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}

extension BrowserSession {
    /// Reads only sources exposed by the page. Segmented/blob streams are not
    /// treated as downloadable files, and scanning never starts a network request.
    func discoverMedia() async throws -> [BrowserMediaCandidate] {
        let script = #"""
            (() => {
                const results = [];
                const seen = new Set();
                const add = (source, title) => {
                    if (!source || results.length >= 40) return;
                    try {
                        const url = new URL(source, document.baseURI);
                        if (!["https:", "http:"].includes(url.protocol) || seen.has(url.href)) return;
                        if (/\.(m3u8|m3u|mpd)$/i.test(url.pathname)) return;
                        seen.add(url.href);
                        results.push({url: url.href, title: (title || document.title || "").slice(0, 160)});
                    } catch {}
                };
                const read = (doc, depth) => {
                    for (const media of doc.querySelectorAll("video, audio")) {
                        if (media.mediaKeys) continue;
                        add(media.currentSrc || media.src, media.title || doc.title);
                        for (const source of media.querySelectorAll("source[src]")) add(source.src, media.title || doc.title);
                    }
                    for (const link of doc.querySelectorAll("a[href]")) {
                        if (/\.(mp4|m4v|mov|mp3|m4a|aac|wav|aif|aiff|caf|flac|ogg|oga|webm)(\?|#|$)/i.test(link.href))
                            add(link.href, link.textContent.trim());
                    }
                    if (depth < 2) for (const frame of doc.querySelectorAll("iframe")) {
                        try { if (frame.contentDocument) read(frame.contentDocument, depth + 1); } catch {}
                    }
                };
                read(document, 0);
                return results;
            })()
            """#
        let result = try await webView.evaluateJavaScript(script)
        var candidates = (result as? [[String: String]] ?? []).compactMap {
            entry -> BrowserMediaCandidate? in
            guard let value = entry["url"], let url = URL(string: value),
                BrowserMediaPolicy.isDirectURL(url)
            else { return nil }
            return BrowserMediaCandidate(url: url, title: entry["title"] ?? "")
        }
        if let url, BrowserMediaPolicy.isDirectURL(url),
            BrowserMediaPolicy.isMediaFile(url),
            !candidates.contains(where: { $0.url == url })
        {
            candidates.insert(
                BrowserMediaCandidate(url: url, title: title),
                at: 0
            )
        }
        return candidates
    }
}
