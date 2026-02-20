//
//  ThemeManager.swift
//  Meowbah
//
//  Created by Ryan Reid on 01/09/2025.
//

import SwiftUI
import Combine

enum AppTheme: Int, CaseIterable, Identifiable {
    case pink = 0
    case lavender = 1
    case mint = 2

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .pink: return "Pink"
        case .lavender: return "Lavender"
        case .mint: return "Mint"
        }
    }
}

struct ThemePalette {
    let primary: Color
    let secondary: Color
    let background: Color
    let card: Color
    let textPrimary: Color
    let textSecondary: Color
    let shadow: Color
}

final class ThemeManager: ObservableObject {
    // Local persistence inside the app container
    @AppStorage("selectedTheme") private var storedTheme: Int = AppTheme.pink.rawValue {
        didSet {
            // Notify observers within the app
            objectWillChange.send()
            // Mirror to the shared App Group so the widget can read it
            writeSharedTheme(storedTheme)
        }
    }

    // MARK: - App Group configuration
    // Replace with your real App Group if it changes in the future.
    private let appGroupID = "group.com.Meowbah"
    private let sharedThemeKey = "selectedTheme"

    init() {
        // On startup, prefer the shared value if present so app and widget are aligned.
        if let shared = UserDefaults(suiteName: appGroupID)?.object(forKey: sharedThemeKey) as? Int,
           AppTheme(rawValue: shared) != nil {
            // This will also write back to local @AppStorage via the setter below
            storedTheme = shared
        } else {
            // Ensure the current local value is mirrored to the shared store
            writeSharedTheme(storedTheme)
        }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: storedTheme) ?? .pink }
        set { storedTheme = newValue.rawValue }
    }

    // MARK: - Shared defaults mirroring

    private func writeSharedTheme(_ value: Int) {
        guard let shared = UserDefaults(suiteName: appGroupID) else { return }
        shared.set(value, forKey: sharedThemeKey)
        // Not strictly necessary, but ensures the value is flushed promptly.
        shared.synchronize()
    }

    // Compute a palette for a given color scheme (no stored scheme needed).
    func palette(for colorScheme: ColorScheme) -> ThemePalette {
        switch (theme, colorScheme) {
        case (.pink, .light):
            return ThemePalette(
                primary: Color.cutePink,
                secondary: Color.cutePeach,
                background: Color.cuteBackground,
                card: Color.cuteCard,
                textPrimary: Color.cuteTextPrimary,
                textSecondary: Color.cuteTextSecondary,
                shadow: Color.cuteShadow
            )
        case (.pink, .dark):
            return ThemePalette(
                primary: Color.cutePink,
                secondary: Color.cutePeach,
                background: Color(red: 0.5, green: 0.1, blue: 0.3),
                card: Color(red: 0.4, green: 0.1, blue: 0.2),
                textPrimary: .white,
                textSecondary: Color(red: 0.95, green: 0.88, blue: 0.93),
                shadow: .black
            )
        case (.lavender, .light):
            return ThemePalette(
                primary: Color.cuteLavender,
                secondary: Color.cutePink,
                background: Color.cuteBackground,
                card: Color.cuteCard,
                textPrimary: Color.cuteTextPrimary,
                textSecondary: Color.cuteTextSecondary,
                shadow: Color.cuteShadow
            )
        case (.lavender, .dark):
            return ThemePalette(
                primary: Color.cuteLavender,
                secondary: Color.cutePink,
                background: Color(red: 0.10, green: 0.09, blue: 0.15),
                card: Color(red: 0.17, green: 0.15, blue: 0.22),
                textPrimary: .white,
                textSecondary: Color(red: 0.90, green: 0.88, blue: 0.95),
                shadow: .black
            )
        case (.mint, .light):
            return ThemePalette(
                primary: Color.cuteMint,
                secondary: Color.cutePeach,
                background: Color.cuteBackground,
                card: Color.cuteCard,
                textPrimary: Color.cuteTextPrimary,
                textSecondary: Color.cuteTextSecondary,
                shadow: Color.cuteShadow
            )
        case (.mint, .dark):
            return ThemePalette(
                primary: Color.cuteMint,
                secondary: Color.cutePeach,
                background: Color(red: 0.08, green: 0.12, blue: 0.10),
                card: Color(red: 0.14, green: 0.18, blue: 0.16),
                textPrimary: .white,
                textSecondary: Color(red: 0.85, green: 0.92, blue: 0.90),
                shadow: .black
            )
        @unknown default:
            return ThemePalette(
                primary: Color.cutePink,
                secondary: Color.cutePeach,
                background: Color.cuteBackground,
                card: Color.cuteCard,
                textPrimary: Color.cuteTextPrimary,
                textSecondary: Color.cuteTextSecondary,
                shadow: Color.cuteShadow
            )
        }
    }
}
