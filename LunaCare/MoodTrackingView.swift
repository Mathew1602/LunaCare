//
//  MoodTrackingView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//

import SwiftUI

enum Mood: String, CaseIterable, Identifiable {
    case ecstatic = "🤩", happy = "😊", okay = "😐", sad = "😕", angry = "😠"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ecstatic: return "Ecstatic"
        case .happy:    return "Happy"
        case .okay:     return "Okay"
        case .sad:      return "Sad"
        case .angry:    return "Angry"
        }
    }
}

struct MoodEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let mood: Mood
    let note: String
}

struct MoodTrackingView: View {
    @State private var selectedMood: Mood? = nil
    @State private var note: String = ""
    @State private var showSavedAlert = false
    @FocusState private var noteFocused: Bool
    @State private var entries: [MoodEntry] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mood Tracking")
                    .font(.title2).bold()
                    .padding(.horizontal)

                MoodPickerGrid(selectedMood: $selectedMood)

                NoteBox(note: $note, focused: _noteFocused)

                Button(action: saveEntry) {
                    Text("Save Mood")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedMood == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Mood Tracking")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { noteFocused = false }
                }
            }
        }
        .alert("Your mood journal has been saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func saveEntry() {
        // A) allow default mood if not picked:
        let mood: Mood = selectedMood ?? .okay
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entries.append(MoodEntry(mood: mood, note: trimmed))

        // reset UI
        selectedMood = nil
        note = ""
        noteFocused = false
        showSavedAlert = true
    }
}

struct MoodPickerGrid: View {
    @Binding var selectedMood: Mood?
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Mood.allCases) { mood in
                Button {
                    selectedMood = mood
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 6) {
                        Text(mood.rawValue)
                            .font(.system(size: 36))
                            .padding(10)
                            .background(
                                Circle()
                                    .stroke(selectedMood == mood ? Color.blue : Color.clear, lineWidth: 3)
                            )
                        Text(mood.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mood.label)
                .accessibilityAddTraits(selectedMood == mood ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .padding(.horizontal)
    }
}

struct NoteBox: View {
    @Binding var note: String
    @FocusState var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $note)
                .frame(minHeight: 120)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.3)))
                .focused($focused)

            if note.isEmpty {
                Text("Write a short note…")
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal)
    }
}


#Preview {
    MoodTrackingView()
}
