//
//  MoodCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//

import SwiftUI

struct MoodCalendarView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = MoodCalendarViewModel()

    private let cols = Array(repeating: GridItem(.flexible()), count: 7)
    //private let noteTint = Color(red: 139/255, green: 146/255, blue: 250/255)
    private let noteTint = Color(.systemIndigo)
    private let tileBG   = Color(red: 249/255, green: 248/255, blue: 255/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Month header
                    HStack(spacing: 12) {
                        Button { Task { await vm.setMonth(delta: -1, uid: auth.uid) } } label: {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(vm.monthTitle).font(.headline)
                        Spacer()
                        Button { Task { await vm.setMonth(delta: 1, uid: auth.uid) } } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(.horizontal, 20)

                    // Weekday titles
                    HStack {
                        ForEach(vm.weekdaySymbols, id: \.self) { s in
                            Text(s)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)

                    if vm.loading {
                        ProgressView().frame(maxWidth: .infinity)
                    }

                    // Days grid
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(vm.daysGrid, id: \.self) { day in
                            DayCell(
                                date: day,
                                selected: vm.selected,
                                mood: vm.latestMood(for: day)
                            ) {
                                if let d = day { vm.selected = d }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    Divider()

                    // Selected day's details: multiple notes (latest first), each as its own block
                    if let sel = vm.selected {
                        let dateText = DateFormatter.medium.string(from: sel)
                        let logs = vm.logsForSelected()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(dateText)
                                .font(.headline)
                                .bold()
                                .padding(.horizontal, 20)

                            if logs.isEmpty {
                                HStack(spacing: 8) {
                                    Text("No logs today")
                                        .foregroundStyle(.secondary)
                                        .italic()
                                }
                                .padding(.horizontal, 20)
                            } else {
                                ForEach(logs) { log in
                                    HStack(alignment: .top, spacing: 10) {
                                        // Emoji
                                        Text(log.mood.rawValue)
                                            .font(.title3)
                                            .padding(.top, 2)

                                        // Note + time
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text((log.note ?? "").isEmpty ? "No note" : (log.note ?? ""))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)

                                            Text(DateFormatter.timeShort.string(from: log.createdAt))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        // Edit icon
                                        Image(systemName: "square.and.pencil")
                                            .font(.title3)
                                            .foregroundColor(noteTint)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(tileBG)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(noteTint.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Mood Calendar")
        }
        .task { await vm.load(uid: auth.uid) }
    }
}

private struct DayCell: View {
    let date: Date?
        let selected: Date?
        let mood: Mood?
        let onTap: () -> Void

//        private let accent = Color(red: 139/255, green: 146/255, blue: 250/255)
    private let accent = Color(.systemIndigo)

        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 2) {
                    ZStack {
                        // TODAY circle
                        if isToday {
                            Circle()
                                .fill(accent)
                                .frame(width: 28, height: 28)
                        }

                        // Day number
                        Text(dayText)
                            .font(.callout)
                            .foregroundColor(
                                date == nil
                                ? .clear
                                : (isToday ? .white : .primary)
                            )
                    }

                    // Emoji mood
                    Text(mood?.rawValue ?? " ")
                        .font(.title3)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? accent : .clear, lineWidth: 2)
                )
            }
            .disabled(date == nil)
        }

        private var isToday: Bool {
            guard let d = date else { return false }
            return Calendar.current.isDateInToday(d)
        }

        private var isSelected: Bool {
            guard let d = date, let s = selected else { return false }
            return Calendar.current.isDate(d, inSameDayAs: s)
        }

        private var dayText: String {
            guard let d = date else { return "" }
            return String(Calendar.current.component(.day, from: d))
        }
    }

private extension DateFormatter {
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    static let timeShort: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}

#Preview {
    MoodCalendarView()
}
