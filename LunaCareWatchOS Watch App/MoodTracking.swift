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

    private let moodOptions: [Mood] = [.ecstatic, .happy, .okay, .sad, .angry]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("How do you feel?")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(moodOptions) { mood in
                        moodButton(mood)
                    }
                }

                if let mood = selectedMood {
                    Text(mood.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.indigo)

                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.caption)
                }

                Button {
                    if let mood = selectedMood { saveMood(mood) }
                } label: {
                    Label("Save Mood", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedMood == nil)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Log Mood")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Mood Saved", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Thanks for checking in")
        }
    }

    private func moodButton(_ mood: Mood) -> some View {
        let selected = selectedMood == mood
        return Button {
            selectedMood = mood
            WKInterfaceDevice.current().play(.click)
        } label: {
            Text(mood.rawValue)
                .font(.system(size: 26))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.indigo.opacity(selected ? 0.45 : 0.12), in: Circle())
                .overlay(Circle().stroke(Color.indigo, lineWidth: selected ? 2 : 0))
                .scaleEffect(selected ? 1.08 : 1)
                .animation(.easeInOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }

    private func saveMood(_ mood: Mood) {
        let moodLog = MoodLog(
            id: nil,
            mood: mood.score,
            notes: note.isEmpty ? nil : note,
            tags: ["watch"],
            source: "watch",
            createdAt: Date(),
            updatedAt: Date()
        )
        WatchConnectivityManager.shared.send(moodLog, type: .moodLog)

        selectedMood = nil
        note = ""
        WKInterfaceDevice.current().play(.success)
        showingSavedAlert = true
    }
}

#Preview {
    MoodTracking()
}
