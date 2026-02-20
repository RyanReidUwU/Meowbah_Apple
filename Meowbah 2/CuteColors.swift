//
//  CuteColors.swift
//  Meowbah
//
//  Created by Ryan Reid on 25/08/2025.
//

import SwiftUI

extension Color {
    static let cutePink = Color(red: 0.98, green: 0.58, blue: 0.74)      // rosy pink
    static let cutePeach = Color(red: 1.00, green: 0.78, blue: 0.80)     // peachy pink
    static let cuteLavender = Color(red: 0.82, green: 0.76, blue: 0.94)  // soft lavender
    static let cuteMint = Color(red: 0.75, green: 0.93, blue: 0.86)      // mint pastel
    static let cuteCream = Color(red: 1.00, green: 0.95, blue: 0.97)     // very light pinkish cream

    static let cuteBackground = Color.cuteCream
    // Darken card slightly for better contrast on light background
    static let cuteCard = Color.white.opacity(0.96)

    static let cuteTextPrimary = Color(red: 0.25, green: 0.15, blue: 0.25)
    static let cuteTextSecondary = Color(red: 0.45, green: 0.35, blue: 0.45)

    static let cuteShadow = Color.black
}
