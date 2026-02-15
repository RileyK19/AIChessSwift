//
//  Colors.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import SwiftUI

// MARK: - App Colors
// If you want to customise board colours, change these.
// Alternatively you can add "LightSquare" and "DarkSquare" named colors
// to your Assets.xcassets and they'll be picked up automatically.

extension Color {
    // Fallbacks used when asset catalog colors are not present
    static let lightSquareFallback = Color(red: 0.93, green: 0.85, blue: 0.73)  // cream
    static let darkSquareFallback  = Color(red: 0.47, green: 0.60, blue: 0.34)  // forest green
}

// SwiftUI Color("name") will automatically use the asset catalog if the color
// exists there, so just add named colors to Assets.xcassets to override.
