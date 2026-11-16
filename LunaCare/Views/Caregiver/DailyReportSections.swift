//
//  DailyReportSections.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

/// Mood and symptom sections for one day, showing only what the mother shared.
/// Used by both the Today tab and a day's detail in History.
struct DailyReportSections: View {
    let report: DailyReport?
    let mother: LinkedMother

    var body: some View {
        if !mother.permissions.mood && !mother.permissions.symptoms {
            Section {
                Text("\(mother.name) hasn't shared her daily reports with you.")
                    .foregroundColor(.secondary)
            }
        }

        if mother.permissions.mood {
            Section("Mood") {
                if let mood = report?.mood {
                    HStack(spacing: 12) {
                        Text(mood.rawValue).font(.largeTitle)
                        Text(mood.label).font(.headline)
                    }
                } else {
                    Text("Not logged").foregroundColor(.secondary)
                }
            }
        }

        if mother.permissions.symptoms {
            Section("Symptoms") {
                let symptoms = report?.reportedSymptoms ?? []
                if symptoms.isEmpty {
                    Text("None reported").foregroundColor(.secondary)
                } else {
                    ForEach(symptoms, id: \.name) { symptom in
                        HStack {
                            Text(symptom.name)
                            Spacer()
                            SymptomLevelBadge(level: symptom.level)
                        }
                    }
                }
            }
        }
    }
}

struct SymptomLevelBadge: View {
    let level: SymptomLevel

    private var color: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var body: some View {
        Text(level.label)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}
