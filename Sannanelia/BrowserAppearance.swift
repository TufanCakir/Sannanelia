//
//  BrowserAppearance.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI

enum BrowserAppearance {

    // MARK: - Appearance

    static func isDark(_ scheme: ColorScheme) -> Bool {
        scheme == .dark
    }

    static func isLight(_ scheme: ColorScheme) -> Bool {
        scheme == .light
    }

    // MARK: - Symbols

    static func symbol(
        _ scheme: ColorScheme,
        light: String = "sun.max",
        dark: String = "moon"
    ) -> String {
        scheme == .dark ? dark : light
    }

    // MARK: - Browser Symbols

    static func securitySymbol(
        isSecure: Bool
    ) -> String {
        isSecure ? "lock.fill" : "lock.open"
    }

    static func loadingSymbol(
        isLoading: Bool
    ) -> String {
        isLoading ? "xmark" : "arrow.clockwise"
    }

    static func tabSymbol(
        isPrivate: Bool
    ) -> String {
        isPrivate ? "hand.raised" : "square.on.square"
    }

    // MARK: - Dynamic Symbols

    static func symbol(
        when condition: Bool,
        trueSymbol: String,
        falseSymbol: String
    ) -> String {
        condition ? trueSymbol : falseSymbol
    }
}
