//
//  MoodTrackingView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
// Updated by Fernanda
//  Updated by Xiaoya Zou, following MVVM

import SwiftUI

struct MoodTrackingView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = MoodTrackingViewModel()
    @FocusState private var noteFocused: Bool

    // Custom border color for the note text editor
    private let noteBorder = Color(red: 139/255, green: 146/255, blue: 250/255)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
//                Text("Mood Tracking")
//                    .font(.title2).bold()
//                    .padding(.horizontal)

                MoodPickerGrid(selectedMood: $vm.selectedMood)

                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        "Date & Time",
                        selection: $vm.createdAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Color(red: 139/255, green: 146/255, blue: 250/255))
                    .foregroundColor(Color(red: 139/255, green: 146/255, blue: 250/255))
                }
                .padding(.horizontal)

                NoteBox(note: $vm.note, focused: _noteFocused, borderColor: noteBorder)

                // Save button
                Button {
                    Task{
                        await vm.save(uid: auth.uid)
                    }
                } label: {
                    HStack {
                        if vm.loading {
                            ProgressView()
                                .tint(Color(.systemIndigo))
                        } else {
                            Text("Save Mood")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        vm.loading || (vm.selectedMood == nil &&
                        vm.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        ? Color.gray.opacity(0.15)
                        : Color(.systemIndigo).opacity(0.2)
                    )
                    .foregroundColor(
                        vm.loading || (vm.selectedMood == nil &&
                        vm.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        ? .gray
                        : Color(.systemIndigo)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                .disabled(vm.loading || (vm.selectedMood == nil &&
                    vm.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                Spacer()
            }
            .navigationTitle("Mood Tracking")
//            .toolbar {
//                ToolbarItemGroup(placement: .keyboard) {
//                    Spacer()
//                    Button("Done") { noteFocused = false }
//                }
//            }
        }
        .alert("Your mood journal has been saved", isPresented: $vm.showSavedAlert) {
            Button("OK", role: .cancel) { }
        }
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
    var borderColor: Color = .gray.opacity(0.3)

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $note)
                .frame(minHeight: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
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
    MoodTrackingView().environmentObject(AuthViewModel())
}

