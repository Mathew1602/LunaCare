//
//  HomeView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Trackers") {
                    NavigationLink {
                        MoodTrackingView()
                    } label: {
                        Label("Mood Tracking", systemImage: "face.smiling")
                    }

                    NavigationLink {
                        SymptomsTrackingView()
                    } label: {
                        Label("Symptoms Tracking", systemImage: "cross.case")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Home")
        }
    }
}
