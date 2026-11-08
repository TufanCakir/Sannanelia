//
//  BrowserVideoDetector.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 08.11.26.
//

import Foundation
import WebKit

struct BrowserDetectedVideo: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL?
}

@MainActor
final class BrowserVideoDetector: NSObject, WKScriptMessageHandler {
    var onVideoDetected: ((BrowserDetectedVideo) -> Void)?

    static let handlerName = "sannaneliaVideo"

    static let script = """
        (() => {
            if (window.__sannaneliaVideoDetector) return;
            window.__sannaneliaVideoDetector = true;

            const observed = new WeakSet();
            let lastKey = "";
            let lastTime = 0;

            function notify(video) {
                const source = video.currentSrc ||
                    video.src ||
                    video.querySelector("source")?.src || "";

                const key = source || location.href;
                const now = Date.now();

                if (key === lastKey && now - lastTime < 1500) return;
                lastKey = key;
                lastTime = now;

                window.webkit.messageHandlers.sannaneliaVideo.postMessage({
                    title: document.title || "Video",
                    url: source,
                    page: location.href
                });
            }

            function attach(video) {
                if (observed.has(video)) return;
                observed.add(video);

                video.addEventListener("play", () => notify(video));
                video.addEventListener("click", () => notify(video));
            }

            function scan() {
                document.querySelectorAll("video").forEach(attach);
            }

            scan();

            new MutationObserver(scan).observe(document.documentElement, {
                childList: true,
                subtree: true
            });
        })();
        """

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.handlerName,
            let payload = message.body as? [String: String]
        else { return }

        let rawURL = payload["url"] ?? ""
        let url = URL(string: rawURL)
        let page = payload["page"] ?? ""

        let video = BrowserDetectedVideo(
            id: page + "|" + rawURL,
            title: payload["title"] ?? "Video",
            url: url
        )

        onVideoDetected?(video)
    }
}
