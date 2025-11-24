//
//  ContentView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-09-11.
//  Updated by Fernanda

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                HomeView()
            } else {
                LoginView()
            }
        }
        .environmentObject(auth)
        .environmentObject(env)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppEnvironment.shared)
        .environmentObject(AuthViewModel())
}

