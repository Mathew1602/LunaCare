//
//  MoodTracking.swift
//  LunaCare
//
//  Updated to sync with iOS using WatchConnectivityManager
//

import SwiftUI
import WatchKit

struct MoodTracking: View {
    @State private var selectedMood: Mood? = nil
    @State private var navigateToReport = false

    private let moodOptions: [Mood] = [.angry, .sad, .ecstatic, .happy, .okay]

    var body: some View {
        VStack(spacing: 16) {

            Text("How do you feel today?")
                .font(.headline)
                .padding(.top, 8)

            
            HStack(spacing: 20) {
                ForEach(moodOptions) { mood in
                    Button {
                        selectedMood = mood
                    } label: {
                        Text(mood.rawValue)
                            .font(.system(size: 25))
                            .opacity(selectedMood == mood ? 1.0 : 0.6)
                            .scaleEffect(selectedMood == mood ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: selectedMood)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let mood = selectedMood {
                Button("Save Mood") {
                    saveMood(mood)
                }
                .font(.headline)
                .padding(.vertical, 8)
                .padding(.horizontal, 22)
                .background(.ultraThinMaterial)
                .cornerRadius(40)

            }
        }
        .navigationTitle("Log Mood")
        .navigationDestination(isPresented: $navigateToReport) {
            MoodReportView()
        }
    }


    private func saveMood(_ mood: Mood) {
        sendMoodToPhone(mood)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigateToReport = true
        }
    }

    private func sendMoodToPhone(_ mood: Mood) {
        let moodLog = MoodLog(
            id: nil,
            mood: mapMoodToScore(mood),
            notes: nil,
            tags: ["watch"],
            source: "watch",
            createdAt: Date(),
            updatedAt: Date()
        )

        WatchConnectivityManager.shared.send(moodLog, type: .moodLog)
    }

    private func mapMoodToScore(_ mood: Mood) -> Int {
        switch mood {
        case .ecstatic: return 4
        case .happy:    return 2
        case .okay:     return 0
        case .sad:      return -1
        case .angry:    return -2
        }
    }
}

#Preview {
    MoodTracking()
}
