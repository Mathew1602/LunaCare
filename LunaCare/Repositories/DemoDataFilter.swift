import Foundation

/// Identifies seeded demo data (doc ID "seed-…" or `source == "seed"`).
enum DemoDataFilter {

    /// True for seeded demo documents. Use this, never `hideFromDisplay`, anywhere data feeds the
    /// PPD risk score, federated-learning snapshots, insights, exports, or the health summary.
    /// Seed data must never reach those, in any build.
    static func isSeedDocument(id: String, source: String? = nil) -> Bool {
        source == "seed" || id.hasPrefix("seed-")
    }

    /// Debug builds show seed data on display-only screens (calendars, caregiver Today/History)
    /// so demos and tests have history. Release builds always hide it.
    #if DEBUG
    static let showSeedDataOnScreens = true
    #else
    static let showSeedDataOnScreens = false
    #endif

    /// For display-only screens. Hides seed data except in debug builds.
    static func hideFromDisplay(id: String, source: String? = nil) -> Bool {
        isSeedDocument(id: id, source: source) && !showSeedDataOnScreens
    }
}
