//
//  StorageScope.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-11-05.
//

import Foundation
import FirebaseAuth

enum StorageScope {
    static let guest = "guest"

    static var current: String {
        Auth.auth().currentUser?.uid ?? guest
    }

    static func key(_ base: String, scope: String = current) -> String {
        "\(base).\(scope)"
    }

    static func data(forKey base: String) -> Data? {
        migrateLegacyValue(base)
        return UserDefaults.standard.data(forKey: key(base))
    }

    static func set(_ value: Any?, forKey base: String) {
        migrateLegacyValue(base)
        UserDefaults.standard.set(value, forKey: key(base))
    }

    static func object(forKey base: String) -> Any? {
        migrateLegacyValue(base)
        return UserDefaults.standard.object(forKey: key(base))
    }

    static func removeObject(forKey base: String, scope: String = current) {
        UserDefaults.standard.removeObject(forKey: key(base, scope: scope))
    }

    static func adoptGuestData(into uid: String) {
        let defaults = UserDefaults.standard
        let suffix = ".\(guest)"
        for name in defaults.dictionaryRepresentation().keys where name.hasSuffix(suffix) {
            let base = String(name.dropLast(suffix.count))
            let target = key(base, scope: uid)
            if defaults.object(forKey: target) == nil, let value = defaults.object(forKey: name) {
                defaults.set(value, forKey: target)
            }
            defaults.removeObject(forKey: name)
        }
    }

    // Data written before per-user scoping belongs to whoever is signed in when it is first read.
    private static func migrateLegacyValue(_ base: String) {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.object(forKey: base) else { return }
        let scoped = key(base)
        if defaults.object(forKey: scoped) == nil {
            defaults.set(legacy, forKey: scoped)
        }
        defaults.removeObject(forKey: base)
    }
}
