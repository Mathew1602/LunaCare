//
//  MoodTracking.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-23.
//


import SwiftUI

struct MoodTracking: View {
    @State private var selectedMood: String? = nil
    @State private var navigateToReport = false

    var body: some View {
        VStack(spacing: 16) {
            Text("How do you feel today?")
                .font(.headline)
                .padding(.top, 8)

            HStack(spacing: 20) {
                ForEach(["😞", "😐", "😊"], id: \.self) { mood in
                    Button {
                        selectedMood = mood
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            navigateToReport = true
                        }
                    } label: {
                        Text(mood)
                            .font(.largeTitle)
                            .opacity(selectedMood == mood ? 1.0 : 0.6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Log Mood")
        .navigationDestination(isPresented: $navigateToReport) {
            MoodReportView()
        }
    }
}

#Preview {
    MoodTracking()
}
