//
//  MoodHistoryView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI
import Combine

struct MoodHistoryView: View {

    @StateObject private var wc = WatchConnectivityManager.shared
    @State private var history: [CalendarDayLog] = []
    @State private var isLoading: Bool = true

    @State private var showingNoteAlert = false
    @State private var noteToShow: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mood past 7 days")
                    .font(.headline)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                        Spacer()
                    }
                } else if history.isEmpty {
                    Text("No data yet. Please record your mood :)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(history) { log in
                        Button {
                            noteToShow = log.note
                                showingNoteAlert = true
                        } label: {
                            HStack {
                                Text(shortDateFormatter.string(from: log.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(log.mood.rawValue)
                                    .font(.title3)

                                Text(log.mood.label)
                                    .font(.body)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain) // avoid blue button styling
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Mood History")
        .onAppear {
            wc.activate()
            isLoading = true

            let now = Date()
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

            let request = GetRequest(from: sevenDaysAgo, to: now)
            wc.send(request, type: .getMoodRequest)
        }
        .onReceive(
            wc.$lastReceived
                .compactMap { $0 }
        ) { msg in
            print("WATCH MoodHistoryView received SyncMessage of type: \(msg.type)")
            guard msg.type == .getMoodResponse,
                  let logs = msg.getMoodResponse else {
                return
            }

            isLoading = false
            history = logs.sorted { $0.createdAt > $1.createdAt }
        }
        .alert("Mood Note",
               isPresented: $showingNoteAlert,
               actions: {
                   Button("OK", role: .cancel) { }
               },
               message: {
                   Text(noteToShow ?? "No Note")
               }
        )
    }

    private var shortDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "MMM d, h:mm a"
        return df
    }

}

#Preview {
    MoodHistoryView()
}
