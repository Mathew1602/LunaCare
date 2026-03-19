//
//  themeEnum.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-03-18.
//

import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "System"
    case dark = "Dark Mode"
    case light = "Light Mode"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}
