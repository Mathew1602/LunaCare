//
//  MoodTracking.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-16.
//


import SwiftUI
import WatchKit

struct MoodTracking: View {
    @State private var selectedMood: Mood? = nil
    @State private var note: String = ""
    @State private var showingSavedAlert = false

    private let moodOptions: [Mood] = [.angry, .sad, .ecstatic, .happy, .okay]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("How do you feel today?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    ForEach(moodOptions) { mood in
                        Button {
                            selectedMood = mood
                        } label: {
                            Text(mood.rawValue)
                                .font(.system(size: 24))
                                .opacity(selectedMood == mood ? 1.0 : 0.5)
                                .scaleEffect(selectedMood == mood ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: selectedMood)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if selectedMood != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add a note")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        TextField("Optional note", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .font(.caption2)
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let mood = selectedMood {
                    Button {
                        saveMood(mood)
                    } label: {
                        Text("Save Mood")
                            .font(.headline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(40)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("Log Mood")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Mood Saved",
               isPresented: $showingSavedAlert,
               actions: {
                   Button("OK", role: .cancel) { }
               },
               message: {
                   Text("Thanks for checking in")
               })
    }

    private func saveMood(_ mood: Mood) {
        sendMoodToPhone(mood)

        // Reset UI
        selectedMood = nil
        note = ""

        // Haptic + alert
        WKInterfaceDevice.current().play(.success)
        showingSavedAlert = true
    }

    private func sendMoodToPhone(_ mood: Mood) {
        let moodLog = MoodLog(
            id: nil,
            mood: mapMoodToScore(mood),
            notes: note.isEmpty ? nil : note,
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
