//
//  BrowserConsoleStore.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation
import Observation

enum BrowserConsoleLevel: String {
    case command
    case result
    case log
    case info
    case warn
    case error
    case debug
}

struct BrowserConsoleMessage: Identifiable {
    let id = UUID()
    let level: BrowserConsoleLevel
    let text: String
    let date = Date()
}

@MainActor
@Observable
final class BrowserConsoleStore {

    private(set) var messages: [BrowserConsoleMessage] = []

    private let maximumMessages = 500

    func append(level: String, text: String) {
        let kind = BrowserConsoleLevel(rawValue: level) ?? .log
        append(level: kind, text: text)
    }

    func append(level: BrowserConsoleLevel, text: String) {
        messages.append(
            BrowserConsoleMessage(
                level: level,
                text: text
            )
        )

        if messages.count > maximumMessages {
            messages.removeFirst(messages.count - maximumMessages)
        }
    }

    func clear() {
        messages.removeAll()
    }
}
