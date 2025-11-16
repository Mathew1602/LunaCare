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
    @State private var days: [SymptomDaySummary] = []
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
                } else if days.isEmpty {
                    Text("No symptom data yet.\nTap the button to fetch.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    ForEach(sortedDays) { day in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayTitleFormatter.string(from: day.date))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.bottom, 2)

                            ForEach(day.rows) { row in
                                HStack {
                                    Text(row.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(row.value)")
                                        .font(.caption)
                                        .bold()
                                }
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
            let to = Calendar.current.startOfDay(for: now)

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
            days = summaries
        }
    }

    // Newest → oldest
    private var sortedDays: [SymptomDaySummary] {
        days.sorted { $0.date > $1.date }
    }

    private var dayTitleFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }
}

#Preview {
    SymptomHistoryView()
}
