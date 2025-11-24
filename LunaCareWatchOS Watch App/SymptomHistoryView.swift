//
//  SymptomHistoryView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-16.
//

import SwiftUI
import Combine

struct SymptomHistoryView: View {

    @StateObject private var wc = WatchConnectivityManager.shared
    @State private var logs: [SymptomLogSummary] = []
    @State private var isLoading: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Symptoms (Last 5 Days)")
                    .font(.headline)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                        Spacer()
                    }
                } else if logs.isEmpty {
                    Text("No symptom data yet.\nLog symptoms from the tracking screen.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    ForEach(groupedByDay, id: \.date) { section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayFormatter.string(from: section.date))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.bottom, 2)

                            ForEach(section.entries) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(timeFormatter.string(from: entry.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    ForEach(entry.rows) { row in
                                        HStack {
                                            Text(row.name)
                                                .font(.caption2)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(row.value)")
                                                .font(.caption2)
                                                .bold()
                                        }
                                    }
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Symptoms")
        .onAppear {
            wc.activate()
            isLoading = true

            let now = Date()
            let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: now) ?? now
            let from = Calendar.current.startOfDay(for: fiveDaysAgo)
            let to = now

            let request = GetRequest(from: from, to: to)
            wc.send(request, type: .getSymptomRequest)
        }
        .onReceive(
            wc.$lastReceived
                .compactMap { $0 }
        ) { msg in
            print("WATCH SymptomHistoryView received SyncMessage of type: \(msg.type)")
            guard msg.type == .getSymptomResponse,
                  let summaries = msg.getSymptomResponse else {
                return
            }
            isLoading = false
            logs = summaries.sorted { $0.createdAt > $1.createdAt }
        }
    }

    // Group logs by calendar day
    private var groupedByDay: [(date: Date, entries: [SymptomLogSummary])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: logs) { log in
            cal.startOfDay(for: log.createdAt)
        }

        return groups
            .map { key, values in
                (date: key, entries: values.sorted { $0.createdAt > $1.createdAt })
            }
            .sorted { $0.date > $1.date }
    }

    private var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }
}

#Preview {
    SymptomHistoryView()
}
