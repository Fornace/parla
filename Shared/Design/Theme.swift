import Foundation
import SwiftUI

/// Flat, printed-page design tokens. No gradients anywhere.
enum Theme {
    // Light: warm paper. Dark: quiet ink.
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x131210) : Color(hex: 0xF6F2EA)
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1D1A16) : Color(hex: 0xFFFDF8)
    }
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF3EEE4) : Color(hex: 0x1B1917)
    }
    static func inkSoft(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xB4ADA2) : Color(hex: 0x5B5449)
    }
    static func line(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x342F27) : Color(hex: 0xDCD3C0)
    }
    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xE48256) : Color(hex: 0xAC5230)
    }
    /// Accent used for small type, where the fill colour is too light to read.
    static func accentInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF0966C) : Color(hex: 0x8C3F1F)
    }

    static func moss(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x8FB394) : Color(hex: 0x496649)
    }

    // The conversation happens on a stage, independent of appearance.
    static let stage = Color(hex: 0x14120F)
    static let stageInk = Color(hex: 0xF4EFE5)
    static let stageSoft = Color(hex: 0x8C8578)
    static let stageAccent = Color(hex: 0xE48256)

    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 36
        static let xxl: CGFloat = 56
    }

    enum Radius {
        static let small: CGFloat = 10
        static let card: CGFloat = 18
        static let pill: CGFloat = 999
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    /// Editorial display face for scene titles and the tutor's own words.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// Thin hairline used instead of shadows for separation.
struct Hairline: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle()
            .fill(Theme.line(scheme))
            .frame(height: 1)
    }
}

/// A flat card: solid surface, hairline border, no shadow.
struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = Theme.Space.m
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface(scheme))
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.line(scheme), lineWidth: 1)
            )
    }
}

/// Small caps label used above sections.
struct Eyebrow: View {
    @Environment(\.colorScheme) private var scheme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.label(11, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Theme.inkSoft(scheme))
    }
}
