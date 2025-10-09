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
    var value: Double  // 0...10
}

fileprivate func severityText(_ value: Double) -> String {
    switch Int(value) {
    case 0: return "None"
    case 1...3: return "Mild"
    case 4...6: return "Moderate"
    case 7...8: return "High"
    default: return "Severe"
    }
}

struct SymptomsTrackingView: View {
    @State private var symptoms: [SymptomEntry] = [
        .init(name: "Fatigue",       value: 0),
        .init(name: "Bleeding",      value: 0),
        .init(name: "Hair Loss",     value: 0),
        .init(name: "Appetite",      value: 0),
        .init(name: "Sleep Trouble", value: 0)
    ]

    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach($symptoms) { $symptom in
                        SymptomCard(symptom: $symptom)
                    }

                    Button(action: save) {
                        Text("Save Symptoms")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Symptoms Tracking")
        }
        .alert("Your symptoms have been saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func save() {
        // mock “persist”: print to console; wire to real storage later
        for s in symptoms {
            print("\(s.name): \(Int(s.value))/10 (\(severityText(s.value)))")
        }
        showSavedAlert = true
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
                Text("\(Int(symptom.value))/10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // slider row
            VStack(alignment: .leading, spacing: 6) {
                Slider(value: $symptom.value, in: 0...10, step: 1)
                HStack {
                    Text("0")
                    Spacer()
                    Text("2")
                    Spacer()
                    Text("4")
                    Spacer()
                    Text("6")
                    Spacer()
                    Text("8")
                    Spacer()
                    Text("10")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Text(severityText(symptom.value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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


#Preview {
    SymptomsTrackingView()
}
