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


// =============================================================
// Theme
// =============================================================

fileprivate enum SymptomTheme {

    static let background = Color.dynamic(light: .white, dark: .black)

    static let card = Color.dynamic(
        light: .white,
        dark:  Color(red: 0.13, green: 0.13, blue: 0.14)
    )
    static let cardBorder = Color.dynamic(
        light: Color(red: 0.91, green: 0.91, blue: 0.91),
        dark:  Color(red: 0.22, green: 0.22, blue: 0.24)
    )
    static let field = Color.dynamic(
        light: Color(red: 0.96, green: 0.96, blue: 0.96),
        dark:  Color(red: 0.19, green: 0.19, blue: 0.21)
    )
    static let ink = Color.dynamic(
        light: Color(red: 0.10, green: 0.10, blue: 0.12),
        dark:  Color(red: 0.96, green: 0.96, blue: 0.94)
    )

    /// Text on top of pastel colours (always dark)
    static let onPastel = Color(red: 0.10, green: 0.10, blue: 0.12)

    static let mint  = Color(red: 0.76, green: 0.91, blue: 0.85)
    static let lime  = Color(red: 0.84, green: 0.94, blue: 0.47)
    static let peach = Color(red: 1.00, green: 0.84, blue: 0.72)
    static let coral = Color(red: 1.00, green: 0.70, blue: 0.66)
    static let lilac = Color(red: 0.89, green: 0.78, blue: 0.97)

    /// Severity scale: lowest level → mint, highest → coral.
    /// Works for any number of SymptomLevel cases.
    static func tint(for level: SymptomLevel) -> Color {
        let scale = [mint, lime, peach, coral]
        let all = Array(SymptomLevel.allCases)

        guard let index = all.firstIndex(of: level), all.count > 1 else {
            return mint
        }

        let position = Double(index) / Double(all.count - 1)
        return scale[Int((position * Double(scale.count - 1)).rounded())]
    }
}


fileprivate extension Color {

    static func dynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}


// =============================================================
// Symptoms Tracking View
// =============================================================

struct SymptomsTrackingView: View {

    @EnvironmentObject var auth: AuthViewModel

    @StateObject private var vm = SymptomTrackingViewModel()

    @State private var navigateToCalendar = false


    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                header

                // =====================================================
                // Symptom Cards
                // =====================================================

                VStack(spacing: 12) {
                    ForEach($vm.symptoms) { $symptom in
                        SymptomCard(symptom: $symptom)
                    }
                }

                saveButton

                if let error = vm.errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )
                }


                // =====================================================
                // Privacy Note
                // =====================================================

                InfoRow(
                    systemImage: "lock.shield.fill",
                    text: "Your symptom check-in is stored securely in your LunaCare health record."
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(SymptomTheme.background.ignoresSafeArea())

        .navigationTitle("Symptoms Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(SymptomTheme.background, for: .navigationBar)


        // =========================================================
        // Navigate to symptom calendar
        // =========================================================

        .navigationDestination(isPresented: $navigateToCalendar) {
            SymptomCalendarView()
        }


        // =========================================================
        // Saved Alert
        // =========================================================

        .alert("Symptoms Saved", isPresented: $vm.showSavedAlert) {

            Button("View Symptom Calendar") {
                navigateToCalendar = true
            }

            Button("Stay Here", role: .cancel) { }

        } message: {
            Text("Your symptom check-in has been saved successfully.")
        }
    }


    // =========================================================
    // Header
    // =========================================================

    private var header: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("How are your symptoms today?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SymptomTheme.ink)

            Text("Select the severity that best matches how each symptom feels right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(loggedCount) of \(vm.symptoms.count) logged")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(
                    loggedCount > 0
                        ? AnyShapeStyle(SymptomTheme.onPastel)
                        : AnyShapeStyle(.secondary)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        loggedCount > 0 ? SymptomTheme.lime : SymptomTheme.field
                    )
                )
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.2), value: loggedCount)
        }
        .padding(.bottom, 4)
    }


    // =========================================================
    // Save Button
    // =========================================================

    private var saveButton: some View {

        Button {

            Task {
                await vm.save(uid: auth.uid)
            }

        } label: {

            HStack(spacing: 10) {

                if vm.isSaving {

                    ProgressView()
                        .tint(SymptomTheme.lime)

                } else {

                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(SymptomTheme.onPastel)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(
                                saveDisabled
                                    ? SymptomTheme.lime.opacity(0.35)
                                    : SymptomTheme.lime
                            )
                        )

                    Text("Save Symptoms")
                        .font(.system(.headline, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundStyle(
                saveDisabled
                    ? AnyShapeStyle(.secondary)
                    : AnyShapeStyle(SymptomTheme.background)
            )
            .background(
                Capsule().fill(
                    saveDisabled ? SymptomTheme.field : SymptomTheme.ink
                )
            )
            .shadow(
                color: saveDisabled ? .clear : .black.opacity(0.15),
                radius: 10,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .disabled(saveDisabled)
        .padding(.top, 4)
    }


    // =========================================================
    // State
    // =========================================================

    private var loggedCount: Int {
        vm.symptoms.filter { $0.level != nil }.count
    }

    private var saveDisabled: Bool {
        !vm.canSave
    }
}


// =============================================================
// Symptom Card
// =============================================================

fileprivate struct SymptomCard: View {

    @Binding var symptom: SymptomEntry


    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack(alignment: .center) {

                Text(symptom.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(SymptomTheme.ink)

                Spacer()

                statusPill
            }

            // Severity selector
            HStack(spacing: 8) {

                ForEach(SymptomLevel.allCases) { level in

                    SymptomLevelButton(
                        level: level,
                        isSelected: symptom.level == level
                    ) {

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            symptom.level = symptom.level == level ? nil : level
                        }

                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SymptomTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(SymptomTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
    }


    @ViewBuilder
    private var statusPill: some View {

        if let level = symptom.level {

            Text(level.label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(SymptomTheme.onPastel)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(SymptomTheme.tint(for: level)))
                .transition(.opacity)

        } else {

            Text("Not reported")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(SymptomTheme.field))
                .transition(.opacity)
        }
    }
}


// =============================================================
// Symptom Level Button
// =============================================================

fileprivate struct SymptomLevelButton: View {

    let level: SymptomLevel
    let isSelected: Bool
    let action: () -> Void


    var body: some View {

        Button(action: action) {

            Text(level.label)
                .font(
                    .system(.caption, design: .rounded)
                        .weight(isSelected ? .semibold : .regular)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(
                        isSelected
                            ? SymptomTheme.tint(for: level)
                            : SymptomTheme.field
                    )
                )
                .foregroundStyle(
                    isSelected
                        ? AnyShapeStyle(SymptomTheme.onPastel)
                        : AnyShapeStyle(.primary)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.label)
        .accessibilityAddTraits(
            isSelected ? [.isButton, .isSelected] : [.isButton]
        )
    }
}


// =============================================================
// Info Row (backend status / privacy)
// =============================================================

fileprivate struct InfoRow: View {

    let systemImage: String
    let text: String

    var body: some View {

        HStack(alignment: .center, spacing: 12) {

            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(SymptomTheme.onPastel)
                .frame(width: 32, height: 32)
                .background(Circle().fill(SymptomTheme.lilac))

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SymptomTheme.lilac.opacity(0.3))
        )
    }
}


#Preview {

    NavigationStack {
        SymptomsTrackingView()
            .environmentObject(AuthViewModel())
    }
}
