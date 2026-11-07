//
//  SannaneliaTheme.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI

enum ThemeManager {

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0x101216)
            : Color(hex: 0xFFFCF5)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0x1D2026)
            : Color(hex: 0xFFF1BF)
    }

    static func foreground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0xF3F3F5)
            : Color(hex: 0x594421)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0xB9BDC7)
            : Color(hex: 0x80663B)
    }

    static func gold(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(hex: 0xE4C47E)
            : Color(hex: 0xCDA34C)
    }
}

extension Color {

    fileprivate init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255,
            opacity: 1
        )
    }
}
