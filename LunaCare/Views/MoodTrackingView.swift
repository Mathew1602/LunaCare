//
//  MoodTrackingView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//  Updated by Fernanda
//  Updated by Xiaoya Zou, following MVVM
//

import SwiftUI


struct MoodTrackingView: View {

    @EnvironmentObject var auth: AuthViewModel

    @StateObject private var vm =
        MoodTrackingViewModel()

    @FocusState private var noteFocused: Bool

    @State private var navigateToCalendar = false


    private let accentColor =
        Color(.systemIndigo)


    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                // =====================================================
                // Header
                // =====================================================

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text("How are you feeling?")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(
                        "Choose the mood that best describes how you feel right now."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }


                // =====================================================
                // Mood Picker Card
                // =====================================================

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    HStack {

                        Label(
                            "Your Mood",
                            systemImage:
                                "face.smiling"
                        )
                        .font(.headline)

                        Spacer()

                        if let mood =
                            vm.selectedMood {

                            Text(mood.label)
                                .font(
                                    .caption.bold()
                                )
                                .foregroundColor(
                                    accentColor
                                )
                                .padding(
                                    .horizontal,
                                    10
                                )
                                .padding(
                                    .vertical,
                                    5
                                )
                                .background(
                                    accentColor
                                        .opacity(0.1)
                                )
                                .clipShape(
                                    Capsule()
                                )
                        }
                    }


                    MoodPickerGrid(
                        selectedMood:
                            $vm.selectedMood
                    )

                }
                .padding()
                .background(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .fill(
                        Color(
                            .secondarySystemGroupedBackground
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        Color.gray
                            .opacity(0.12)
                    )
                )


                // =====================================================
                // Date / Time Card
                // =====================================================

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Label(
                        "Date & Time",
                        systemImage:
                            "calendar"
                    )
                    .font(.headline)


                    DatePicker(
                        "",
                        selection:
                            $vm.createdAt,
                        displayedComponents: [
                            .date,
                            .hourAndMinute
                        ]
                    )
                    .labelsHidden()
                    .datePickerStyle(
                        .compact
                    )
                    .tint(
                        accentColor
                    )

                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .fill(
                        Color(
                            .secondarySystemGroupedBackground
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        Color.gray
                            .opacity(0.12)
                    )
                )


                // =====================================================
                // Note Card
                // =====================================================

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    HStack {

                        Label(
                            "Journal Note",
                            systemImage:
                                "square.and.pencil"
                        )
                        .font(.headline)


                        Spacer()


                        Text(
                            "\(vm.note.count) characters"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    NoteBox(
                        note:
                            $vm.note,
                        focused:
                            _noteFocused,
                        borderColor:
                            accentColor
                                .opacity(0.45)
                    )

                }
                .padding()
                .background(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .fill(
                        Color(
                            .secondarySystemGroupedBackground
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        Color.gray
                            .opacity(0.12)
                    )
                )


                // =====================================================
                // Save Button
                // =====================================================

                Button {

                    noteFocused = false

                    Task {
                        await vm.save(
                            uid: auth.uid
                        )
                    }

                } label: {

                    HStack(
                        spacing: 10
                    ) {

                        if vm.loading {

                            ProgressView()
                                .tint(
                                    .white
                                )

                        } else {

                            Image(
                                systemName:
                                    "checkmark.circle.fill"
                            )

                            Text(
                                "Save Mood"
                            )
                            .fontWeight(
                                .semibold
                            )
                        }

                    }
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(
                        .vertical,
                        15
                    )
                    .background(
                        saveDisabled
                            ? Color.gray
                                .opacity(0.2)
                            : accentColor
                    )
                    .foregroundColor(
                        saveDisabled
                            ? .gray
                            : .white
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                    )
                    .shadow(
                        color:
                            saveDisabled
                                ? .clear
                                : accentColor
                                    .opacity(0.2),
                        radius: 8,
                        y: 4
                    )
                }
                .disabled(
                    saveDisabled
                )


                // =====================================================
                // Privacy Note
                // =====================================================

                HStack(
                    alignment: .top,
                    spacing: 10
                ) {

                    Image(
                        systemName:
                            "lock.shield"
                    )
                    .foregroundColor(
                        accentColor
                    )

                    Text(
                        "Your mood journal is stored securely in your LunaCare health record."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .horizontal,
                    4
                )

            }
            .padding()

        }
        .background(
            Color(
                .systemGroupedBackground
            )
        )

        .navigationTitle(
            "Mood Tracking"
        )

        .navigationBarTitleDisplayMode(
            .inline
        )


        // =========================================================
        // Navigate to calendar after successful save
        // =========================================================

        .navigationDestination(
            isPresented:
                $navigateToCalendar
        ) {

            MoodCalendarView()

        }


        // =========================================================
        // Save success alert
        // =========================================================

        .alert(
            "Mood Saved",
            isPresented:
                $vm.showSavedAlert
        ) {

            Button(
                "View Mood Calendar"
            ) {
                navigateToCalendar =
                    true
            }


            Button(
                "Stay Here",
                role: .cancel
            ) { }

        } message: {

            Text(
                "Your mood journal has been saved successfully."
            )

        }


        // =========================================================
        // Keyboard toolbar
        // =========================================================

        .toolbar {

            ToolbarItemGroup(
                placement: .keyboard
            ) {

                Spacer()

                Button("Done") {
                    noteFocused = false
                }

            }
        }
    }


    // =========================================================
    // Save button state
    // =========================================================

    private var saveDisabled: Bool {

        vm.loading ||
        (
            vm.selectedMood == nil &&
            vm.note
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        )
    }
}


// =============================================================
// Mood Picker
// =============================================================

struct MoodPickerGrid: View {

    @Binding var selectedMood: Mood?

    private let columns:
        [GridItem] =
            Array(
                repeating:
                    GridItem(
                        .flexible(),
                        spacing: 10
                    ),
                count: 5
            )


    var body: some View {

        LazyVGrid(
            columns: columns,
            spacing: 14
        ) {

            ForEach(
                Mood.allCases
            ) { mood in

                Button {

                    selectedMood =
                        mood

                    UIImpactFeedbackGenerator(
                        style: .light
                    )
                    .impactOccurred()

                } label: {

                    VStack(
                        spacing: 8
                    ) {

                        ZStack {

                            Circle()
                                .fill(
                                    selectedMood ==
                                    mood
                                        ? Color(
                                            .systemIndigo
                                        )
                                        .opacity(
                                            0.12
                                        )
                                        : Color(
                                            .systemGray6
                                        )
                                )
                                .frame(
                                    width: 58,
                                    height: 58
                                )


                            Circle()
                                .stroke(
                                    selectedMood ==
                                    mood
                                        ? Color(
                                            .systemIndigo
                                        )
                                        : Color.clear,
                                    lineWidth:
                                        2.5
                                )
                                .frame(
                                    width: 58,
                                    height: 58
                                )


                            Text(
                                mood.rawValue
                            )
                            .font(
                                .system(
                                    size: 32
                                )
                            )
                        }


                        Text(
                            mood.label
                        )
                        .font(
                            .caption2
                        )
                        .fontWeight(
                            selectedMood ==
                            mood
                                ? .semibold
                                : .regular
                        )
                        .foregroundColor(
                            selectedMood ==
                            mood
                                ? Color(
                                    .systemIndigo
                                )
                                : .secondary
                        )
                        .lineLimit(1)
                    }

                }
                .buttonStyle(
                    .plain
                )
                .accessibilityLabel(
                    mood.label
                )
                .accessibilityAddTraits(
                    selectedMood ==
                    mood
                        ? [
                            .isButton,
                            .isSelected
                        ]
                        : [
                            .isButton
                        ]
                )
            }
        }
    }
}


// =============================================================
// Note Box
// =============================================================

struct NoteBox: View {

    @Binding var note: String

    @FocusState var focused: Bool

    var borderColor:
        Color =
            .gray.opacity(0.3)


    var body: some View {

        ZStack(
            alignment: .topLeading
        ) {

            TextEditor(
                text: $note
            )
            .frame(
                minHeight: 120
            )
            .padding(8)
            .scrollContentBackground(
                .hidden
            )
            .background(
                Color(
                    .systemBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12
                )
                .stroke(
                    focused
                        ? Color(
                            .systemIndigo
                        )
                        : borderColor,
                    lineWidth:
                        focused
                            ? 2
                            : 1
                )
            )
            .focused(
                $focused
            )


            if note.isEmpty {

                Text(
                    "Write a short note about how you're feeling..."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .tertiary
                )
                .padding(
                    .top,
                    17
                )
                .padding(
                    .leading,
                    13
                )
                .allowsHitTesting(
                    false
                )
            }
        }
    }
}


#Preview {

    NavigationStack {

        MoodTrackingView()
            .environmentObject(
                AuthViewModel()
            )

    }
}
