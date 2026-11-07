//
//  BrowserConsoleBridge.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation
import WebKit

@MainActor
final class BrowserConsoleBridge: NSObject, WKScriptMessageHandler {
    let store: BrowserConsoleStore

    init(store: BrowserConsoleStore) {
        self.store = store
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "sannaneliaConsole",
            let data = message.body as? [String: Any],
            let level = data["level"] as? String,
            let text = data["text"] as? String
        else {
            return
        }

        store.append(level: level, text: text)
    }
}
