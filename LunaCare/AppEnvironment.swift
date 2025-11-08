//
//  AppEnvironment.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    private init() {}

    @Published var isCloudSyncOn: Bool = false
}
