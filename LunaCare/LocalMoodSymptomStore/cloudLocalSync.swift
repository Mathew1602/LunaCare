//
//  cloudLocalSync.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-03-24.
//

import Foundation


final class cloudLocalSync {
    static let shared = cloudLocalSync()
    
    private var useCloudProvider: () -> Bool = { true }
    private var uidProvider: () -> String = { "" }
    private var env: AppEnvironment?
    
    func configure(
        uidProvider: @escaping () -> String,
        env: AppEnvironment
    ) {
        self.uidProvider = uidProvider
        self.env = env
        self.useCloudProvider = { env.isCloudSyncOn }
    }
    
    func isUsingCloud() -> Bool {
        useCloudProvider()
    }
    
    

}
