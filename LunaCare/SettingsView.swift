//
//  SettingsView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profile")) {
                    NavigationLink("Account") { Text("Account Details") }
                    NavigationLink("Caregiver Links") { Text("Caregiver Links") }
                }
                
                Section(header: Text("Privacy & Security")) {
                    NavigationLink("Data Privacy") { Text("Data Privacy Settings") }
                    NavigationLink("Data Export") { Text("Data Export Options") }
                }
                
                Section(header: Text("App Preferences")) {
                    NavigationLink("Notifications") { Text("Notification Settings") }
                    NavigationLink("Theme") { Text("Theme Options") }
                    NavigationLink("Language") { Text("Language Settings") }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    SettingsView()
}
