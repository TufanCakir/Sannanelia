import SwiftUI

enum ThemeManager {
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x17130F) : Color(hex: 0xFFFCF5)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x292218) : Color(hex: 0xFFF1BF)
    }

    static func foreground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF4E6C6) : Color(hex: 0x594421)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xD6B66C) : Color(hex: 0x80663B)
    }

    static func gold(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xD6B66C) : Color(hex: 0xCDA34C)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}
