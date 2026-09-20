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

    var value: Double { Double(level?.rawValue ?? 0) }
}

struct SymptomsTrackingView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = SymptomTrackingViewModel()

    var body: some View {
        NavigationStack {
                VStack(spacing: 16) {
                    ForEach($vm.symptoms) { $symptom in
                        SymptomCard(symptom: $symptom)
                    }

                    Button {
                        Task{
                           await vm.save(uid: auth.uid)
                        }
                    } label: {
                        Text("Save Symptoms")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.top, 4)

                    if let status = vm.backendStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
            }
             .padding(.vertical, 8)
            .navigationTitle("Symptoms Tracking")
        }
        .alert("Your symptoms have been saved", isPresented: $vm.showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let status = vm.backendStatus {
                Text(status)
            }
        }
    }
}

fileprivate struct SymptomCard: View {
    @Binding var symptom: SymptomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(symptom.name)
                    .font(.headline)
                Spacer()
                Text(symptom.level?.label ?? "Not reported")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(SymptomLevel.allCases) { level in
                    SymptomLevelButton(
                        level: level,
                        isSelected: symptom.level == level
                    ) {
                        symptom.level = (symptom.level == level) ? nil : level
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

fileprivate struct SymptomLevelButton: View {
    let level: SymptomLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(level.label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected
                              ? Color(.systemIndigo).opacity(0.2)
                              : Color(.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color(.systemIndigo) : Color(.separator),
                                lineWidth: isSelected ? 2 : 1)
                )
                .foregroundStyle(isSelected ? Color(.systemIndigo) : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

#Preview {
    SymptomsTrackingView()
        .environmentObject(AuthViewModel())
}
