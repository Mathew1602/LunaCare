//
//  SymptomHistoryView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-16.
//

import SwiftUI
import Combine

struct SymptomHistoryView: View {
    @ObservedObject private var wc = WatchConnectivityManager.shared
    @State private var logs: [SymptomLogSummary] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Past 7 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else if logs.isEmpty {
                    WatchEmptyState(icon: "cross.case", text: "No symptoms yet. Log them from the home screen.")
                } else {
                    ForEach(logs) { entry in
                        card(entry)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Symptoms")
        .onAppear {
            wc.activate()
            isLoading = true
            let now = Date()
            let cal = Calendar.current
            let from = cal.startOfDay(for: cal.date(byAdding: .day, value: -6, to: now) ?? now)
            wc.send(GetRequest(from: from, to: now), type: .getSymptomRequest)
        }
        .onReceive(wc.$lastReceived.compactMap { $0 }) { msg in
            guard msg.type == .getSymptomResponse, let summaries = msg.getSymptomResponse else { return }
            isLoading = false
            logs = summaries.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func card(_ entry: SymptomLogSummary) -> some View {
        let active = entry.rows.filter { $0.value > 0 }
        return VStack(alignment: .leading, spacing: 4) {
            Text(entry.createdAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.footnote.weight(.semibold))

            if active.isEmpty {
                Text("No symptoms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(active) { row in
                    HStack {
                        Text(row.name)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(SymptomLevel(rawValue: row.value)?.label ?? "\(row.value)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(SymptomLevel.tint(forValue: row.value).opacity(0.4), in: Capsule())
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    SymptomHistoryView()
}
