//
//  MoodHistoryView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI
import Combine

struct MoodHistoryView: View {
    @ObservedObject private var wc = WatchConnectivityManager.shared
    @State private var history: [CalendarDayLog] = []
    @State private var isLoading = true
    @State private var noteToShow: String? = nil

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
                } else if history.isEmpty {
                    WatchEmptyState(icon: "face.smiling", text: "No moods yet. Log one from the home screen.")
                } else {
                    ForEach(history) { log in
                        Button {
                            noteToShow = log.note ?? "No note"
                        } label: {
                            row(log)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Moods")
        .onAppear {
            wc.activate()
            isLoading = true
            let now = Date()
            let from = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            wc.send(GetRequest(from: from, to: now), type: .getMoodRequest)
        }
        .onReceive(wc.$lastReceived.compactMap { $0 }) { msg in
            guard msg.type == .getMoodResponse, let logs = msg.getMoodResponse else { return }
            isLoading = false
            history = logs.sorted { $0.createdAt > $1.createdAt }
        }
        .alert("Mood Note", isPresented: Binding(get: { noteToShow != nil }, set: { if !$0 { noteToShow = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(noteToShow ?? "")
        }
    }

    private func row(_ log: CalendarDayLog) -> some View {
        HStack(spacing: 8) {
            Text(log.mood.rawValue)
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 1) {
                Text(log.mood.label)
                    .font(.footnote.weight(.semibold))
                Text(log.createdAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            if log.note?.isEmpty == false {
                Image(systemName: "note.text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    MoodHistoryView()
}
