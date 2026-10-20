//
//  SymptomsTrackingView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//

import SwiftUI


struct SymptomEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String

    var level: SymptomLevel? = nil

    var value: Double {
        Double(level?.rawValue ?? 0)
    }
}


struct SymptomsTrackingView: View {

    @EnvironmentObject var auth: AuthViewModel

    @StateObject private var vm =
        SymptomTrackingViewModel()

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

                    Text("How are your symptoms today?")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(
                        "Select the severity that best matches how each symptom feels right now."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }


                // =====================================================
                // Symptom Cards
                // =====================================================

                VStack(
                    spacing: 14
                ) {

                    ForEach(
                        $vm.symptoms
                    ) { $symptom in

                        SymptomCard(
                            symptom:
                                $symptom,
                            accentColor:
                                accentColor
                        )
                    }
                }


                // =====================================================
                // Save Button
                // =====================================================

                Button {

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
                                .tint(.white)

                        } else {

                            Image(
                                systemName:
                                    "checkmark.circle.fill"
                            )

                            Text(
                                "Save Symptoms"
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
                // Backend Status
                // =====================================================

                if let status =
                    vm.backendStatus {

                    HStack(
                        alignment: .top,
                        spacing: 10
                    ) {

                        Image(
                            systemName:
                                "icloud.and.arrow.up"
                        )
                        .foregroundColor(
                            accentColor
                        )

                        Text(status)
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
                        "Your symptom check-in is stored securely in your LunaCare health record."
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
            "Symptoms Tracking"
        )

        .navigationBarTitleDisplayMode(
            .inline
        )


        // =========================================================
        // Navigate to symptom calendar
        // =========================================================

        .navigationDestination(
            isPresented:
                $navigateToCalendar
        ) {

            SymptomCalendarView()

        }


        // =========================================================
        // Saved Alert
        // =========================================================

        .alert(
            "Symptoms Saved",
            isPresented:
                $vm.showSavedAlert
        ) {

            Button(
                "View Symptom Calendar"
            ) {
                navigateToCalendar =
                    true
            }


            Button(
                "Stay Here",
                role: .cancel
            ) { }

        } message: {

            if let status =
                vm.backendStatus {

                Text(status)

            } else {

                Text(
                    "Your symptom check-in has been saved successfully."
                )
            }
        }
    }


    // =========================================================
    // Save Button State
    // =========================================================

    private var saveDisabled: Bool {

        vm.loading ||
        !vm.symptoms.contains {
            $0.level != nil
        }
    }
}


// =============================================================
// Symptom Card
// =============================================================

fileprivate struct SymptomCard: View {

    @Binding var symptom: SymptomEntry

    let accentColor: Color


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            // Header
            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        symptom.name
                    )
                    .font(
                        .headline
                    )


                    Text(
                        symptom.level?.label
                        ?? "Not reported"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        symptom.level == nil
                            ? .secondary
                            : accentColor
                    )
                }


                Spacer()


                if symptom.level != nil {

                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundColor(
                        accentColor
                    )
                }
            }


            // Severity selector
            HStack(
                spacing: 10
            ) {

                ForEach(
                    SymptomLevel.allCases
                ) { level in

                    SymptomLevelButton(
                        level:
                            level,
                        isSelected:
                            symptom.level == level,
                        accentColor:
                            accentColor
                    ) {

                        symptom.level =
                            symptom.level == level
                                ? nil
                                : level

                        UIImpactFeedbackGenerator(
                            style: .light
                        )
                        .impactOccurred()
                    }
                }
            }
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
                symptom.level != nil
                    ? accentColor
                        .opacity(0.25)
                    : Color.gray
                        .opacity(0.12),
                lineWidth: 1
            )
        )
        .shadow(
            color:
                Color.black
                    .opacity(0.025),
            radius: 5,
            y: 2
        )
    }
}


// =============================================================
// Symptom Level Button
// =============================================================

fileprivate struct SymptomLevelButton: View {

    let level: SymptomLevel
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void


    var body: some View {

        Button(
            action: action
        ) {

            Text(
                level.label
            )
            .font(
                .caption.weight(
                    isSelected
                        ? .semibold
                        : .regular
                )
            )
            .frame(
                maxWidth: .infinity
            )
            .padding(
                .vertical,
                11
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 11
                )
                .fill(
                    isSelected
                        ? accentColor
                            .opacity(0.12)
                        : Color(
                            .tertiarySystemBackground
                        )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 11
                )
                .stroke(
                    isSelected
                        ? accentColor
                        : Color(
                            .separator
                        ),
                    lineWidth:
                        isSelected
                            ? 2
                            : 1
                )
            )
            .foregroundStyle(
                isSelected
                    ? accentColor
                    : Color.primary
            )
        }
        .buttonStyle(
            .plain
        )
        .accessibilityLabel(
            level.label
        )
        .accessibilityAddTraits(
            isSelected
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


#Preview {

    NavigationStack {

        SymptomsTrackingView()
            .environmentObject(
                AuthViewModel()
            )

    }
}
