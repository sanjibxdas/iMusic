import UIKit

enum AppTheme {
    // Apple Music iconic colors
    static let accent = UIColor(red: 250/255, green: 36/255, blue: 60/255, alpha: 1.0) // #FA243C
    static let accentDark = UIColor(red: 215/255, green: 25/255, blue: 45/255, alpha: 1.0)

    // Dark surfaces (optimized for OLED/Retina dark experience)
    static let background = UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0)
    static let surface = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)
    static let surfaceElevated = UIColor(red: 38/255, green: 38/255, blue: 42/255, alpha: 1.0)
    static let separator = UIColor(red: 54/255, green: 54/255, blue: 58/255, alpha: 1.0)

    // Text colors
    static let textPrimary = UIColor(white: 0.98, alpha: 1.0)
    static let textSecondary = UIColor(white: 0.65, alpha: 1.0)
    static let textTertiary = UIColor(white: 0.42, alpha: 1.0)

    // Mini player & glass chrome
    static let miniPlayerBackground = UIColor(red: 24/255, green: 24/255, blue: 26/255, alpha: 0.94)

    // Layout constants
    static let cornerRadiusArtwork: CGFloat = 8.0
    static let cornerRadiusCard: CGFloat = 10.0
    static let cornerRadiusPill: CGFloat = 16.0
    static let miniPlayerHeight: CGFloat = 52.0

    // Typography helpers for iOS 12 San Francisco system font
    static func largeTitleFont() -> UIFont {
        return UIFont.systemFont(ofSize: 34, weight: .bold)
    }

    static func sectionHeaderFont() -> UIFont {
        return UIFont.systemFont(ofSize: 22, weight: .bold)
    }

    static func titleFont() -> UIFont {
        return UIFont.systemFont(ofSize: 17, weight: .semibold)
    }

    static func bodyFont() -> UIFont {
        return UIFont.systemFont(ofSize: 15, weight: .regular)
    }

    static func subheadlineFont() -> UIFont {
        return UIFont.systemFont(ofSize: 13, weight: .regular)
    }

    static func captionFont() -> UIFont {
        return UIFont.systemFont(ofSize: 11, weight: .medium)
    }
}
