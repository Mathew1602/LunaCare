//
//  SymptomCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//  Updated by Mathew to show per-time symptom logs for the selected day.
//

import SwiftUI

struct SymptomCalendarView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = SymptomCalendarViewModel()

    private let cols = Array(repeating: GridItem(.flexible()), count: 7)
    // private let symptomTint = Color(red: 139/255, green: 146/255, blue: 250/255)
    private let symptomTint = Color(.systemIndigo)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - Calendar section
                    VStack(spacing: 12) {
                        Spacer()

                        // Month header
                        HStack {
                            Button {
                                Task { await vm.changeMonth(by: -1, uid: auth.uid) }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(symptomTint)
                                    .font(.title3)
                            }

                            Spacer()

                            Text(vm.monthTitle)
                                .font(.headline)

                            Spacer()

                            Button {
                                Task { await vm.changeMonth(by: 1, uid: auth.uid) }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(symptomTint)
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Weekday row
                        HStack {
                            ForEach(vm.weekdaySymbols, id: \.self) { s in
                                Text(s)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Calendar grid
                        LazyVGrid(columns: cols, spacing: 10) {
                            ForEach(vm.daysGrid, id: \.self) { day in
                                SymptomDayCell(
                                    date: day,
                                    selected: vm.selected,
                                    hasSymptoms: vm.hasSymptoms(on: day),
                                    isToday: vm.isToday(day),
                                    tint: symptomTint
                                ) {
                                    if let d = day {
                                        Task {
                                            await vm.select(day: d, uid: auth.uid)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }

                    Spacer()
                        .frame(height: 24)

                    Divider()

                    // MARK: - Selected day details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(vm.selectedTitle)
                            .font(.headline)

                        if vm.loadingSelected {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if vm.selectedEntries.isEmpty {
                            Text("No symptom logs recorded for this day.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.selectedEntries) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    // Time of this log
                                    Text(timeFormatter.string(from: entry.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    // Symptom rows for this log
                                    ForEach(entry.rows) { row in
                                        HStack {
                                            Text(row.name)
                                                .font(.body)
                                            Spacer()
                                            Text("\(row.value) / 10")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                // load current month when the view appears
                .task {
                    let uid = auth.uid
                    await vm.loadMonth(for: uid)
                }
            }
            .navigationTitle("Symptom Calendar")
        }
        .onDisappear {
            NotificationManager.shared.scheduleDemo(after: 5)
        }
    }

    // MARK: - Formatters

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }
}

private struct SymptomDayCell: View {
    let date: Date?
    let selected: Date?
    let hasSymptoms: Bool
    let isToday: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    // big purple circle for "today"
                    if isToday {
                        Circle()
                            .fill(tint)
                            .frame(width: 28, height: 28)
                    }

                    Text(dayText)
                        .font(.callout)
                        .fontWeight(isToday ? .semibold : .regular)
                        .foregroundStyle(
                            date == nil
                            ? .clear
                            : (isToday ? Color.white : .primary)
                        )
                }

                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .opacity(hasSymptoms ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(date == nil)
    }

    private var dayText: String {
        guard let d = date else { return "" }
        return String(Calendar.current.component(.day, from: d))
    }
}

#Preview {
    SymptomCalendarView()
        .environmentObject(AuthViewModel.preview)
}
