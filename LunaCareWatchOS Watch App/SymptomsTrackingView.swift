//
//  SymptomsTrackingView.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI
import WatchKit

struct SymptomsTrackingView: View {
    private let symptomNames = ["Fatigue", "Bleeding", "Hair Loss", "Appetite", "Sleep Trouble"]

    @State private var levels: [String: SymptomLevel] = [:]
    @State private var showingSavedAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(symptomNames, id: \.self) { name in
                    SymptomLevelRow(title: name, level: binding(for: name))
                }

                Button {
                    sendSymptomLog()
                } label: {
                    Label("Save & Sync", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(levels.isEmpty)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Symptoms")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Symptoms Saved", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your symptom check-in has been synced")
        }
    }

    private func binding(for name: String) -> Binding<SymptomLevel?> {
        Binding(
            get: { levels[name] },
            set: { levels[name] = $0 }
        )
    }

    private func sendSymptomLog() {
        let values = Dictionary(
            uniqueKeysWithValues: symptomNames.map { ($0, levels[$0]?.rawValue ?? 0) }
        )
        let payload = SymptomLogPayload(values: values, notes: nil, tags: ["watch"], source: "watch")
        WatchConnectivityManager.shared.send(payload, type: .symptomLog)

        WKInterfaceDevice.current().play(.success)
        showingSavedAlert = true
        levels.removeAll()
    }
}

struct SymptomLevelRow: View {
    let title: String
    @Binding var level: SymptomLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Spacer()
                if let level {
                    Circle()
                        .fill(level.tint)
                        .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: 4) {
                ForEach(SymptomLevel.allCases) { option in
                    let selected = level == option
                    Button {
                        level = selected ? nil : option
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text(option.label)
                            .font(.caption2.weight(selected ? .bold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(option.tint.opacity(selected ? 0.55 : 0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(option.label)")
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    SymptomsTrackingView()
}
