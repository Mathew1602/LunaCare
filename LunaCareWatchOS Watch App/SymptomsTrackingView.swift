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
            VStack(spacing: 16) {
                Text("Symptoms Tracking")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ForEach(symptomNames, id: \.self) { name in
                    SymptomLevelRow(title: name, level: binding(for: name))
                }

                Button(action: {
                    sendSymptomLog()
                }) {
                    Text("Save & Sync")
                        .font(.body)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(40)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .padding(.vertical)
        }
        .alert("Symptoms Saved",
               isPresented: $showingSavedAlert,
               actions: {
                   Button("OK", role: .cancel) { }
               },
               message: {
                   Text("Your symptom check-in has been synced")
               })
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

        let payload = SymptomLogPayload(
            values: values,
            notes: nil,
            tags: ["watch"],
            source: "watch"
        )

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
            Text(title)
                .font(.body)
                .fontWeight(.semibold)

            HStack(spacing: 6) {
                ForEach(SymptomLevel.allCases) { option in
                    Button {
                        level = (level == option) ? nil : option
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text(option.label)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(level == option
                                  ? Color.accentColor.opacity(0.4)
                                  : Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor,
                                    lineWidth: level == option ? 1.5 : 0)
                    )
                    .accessibilityLabel("\(title), \(option.label)")
                    .accessibilityAddTraits(level == option ? [.isButton, .isSelected] : [.isButton])
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    SymptomsTrackingView()
}
