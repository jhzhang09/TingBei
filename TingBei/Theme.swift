import SwiftUI

// MARK: - 多主题美学系统（当前主题状态与派生色；配色表见 ThemePalette.swift）

@MainActor
@Observable
final class ThemeState {
    static let shared = ThemeState()
    var current: AppTheme = .obsidianGold
}

@MainActor
enum Theme {
    static var current: AppTheme {
        ThemeState.shared.current
    }

    static func apply(_ theme: AppTheme) {
        if ThemeState.shared.current != theme {
            ThemeState.shared.current = theme
        }
    }

    static func palette(for theme: AppTheme) -> ThemePalette {
        ThemePalette.forThemeID(theme.rawValue)
    }

    private static var p: ThemePalette {
        palette(for: current)
    }

    static var bg: Color { p.bg }
    static var raised: Color { p.raised }
    static var surface: Color { p.surface }
    static var cream: Color { p.cream }
    static var mute: Color { p.mute }
    static var faint: Color { p.faint }
    static var gold: Color { p.gold }
    static var goldBright: Color { p.goldBright }
    static var wine: Color { p.wine }
    static var sage: Color { p.sage }
    static var water: Color { p.water }
    static var caution: Color { p.caution }
    static var ink: Color { p.ink }
    static var isLight: Bool { p.isLight }
    static var colorScheme: ColorScheme { p.isLight ? .light : .dark }

    static var borderSubtle: Color {
        isLight ? gold.opacity(0.18) : Color.white.opacity(0.07)
    }

    static var cardShadow: Color {
        isLight ? gold.opacity(0.12) : Color.black.opacity(0.50)
    }

    static var dialShadow: Color {
        isLight ? gold.opacity(0.18) : Color.black.opacity(0.65)
    }

    static func tint(_ cue: Cue) -> Color {
        switch cue {
        case .calm, .settle:
            sage
        // 偏快 / 临线用独立的警示色，不能复用主题主色 gold
        case .hurried, .near:
            caution
        case .due, .over:
            wine
        }
    }

    static var bezelGradient: LinearGradient {
        if isLight {
            return LinearGradient(
                colors: [
                    goldBright.opacity(0.42),
                    gold.opacity(0.18),
                    Color.white.opacity(0.75),
                    gold.opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                goldBright.opacity(0.45),
                gold.opacity(0.15),
                Color.white.opacity(0.04),
                gold.opacity(0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var subtleCardStroke: LinearGradient {
        if isLight {
            return LinearGradient(
                colors: [
                    gold.opacity(0.24),
                    gold.opacity(0.08),
                    goldBright.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.03),
                gold.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var ringSafeGradient: LinearGradient {
        if isLight {
            return LinearGradient(
                colors: [gold, goldBright],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [cream, goldBright],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
