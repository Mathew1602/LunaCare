import Foundation

enum DemoDataFilter {
    static func isSeedDocument(id: String, source: String? = nil) -> Bool {
        source == "seed" || id.hasPrefix("seed-")
    }
}
