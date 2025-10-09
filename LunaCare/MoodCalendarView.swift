//
//  MoodCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//

import SwiftUI

struct MoodCalendarView: View {

    private let headerImageName = "moodCalendar"

    @State private var monthOffset = 0
    @State private var selected: Date? = nil
    @State private var moodByDay: [Date: Mood] = [:]

    private let cal = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

//                    Text("Mood Calendar")
//                        .font(.title2).bold()
//                        .padding(.horizontal)

                    // header illustration
                    Image(headerImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(18)
                        .padding(.horizontal)

                    // month header
                    HStack(spacing: 12) {
                        Button { monthOffset -= 1; seedMock() } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(monthTitle).font(.headline)
                        Spacer()
                        Button { monthOffset += 1; seedMock() } label: { Image(systemName: "chevron.right") }
                    }
                    .padding(.horizontal)

                    // weekday titles
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { s in
                            Text(s).font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)

                    // days grid
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(daysGrid, id: \.self) { day in
                            DayCell(
                                date: day,
                                selected: selected,
                                mood: moodByDay[day?.startOfDay ?? .distantPast]
                            ) {
                                if let d = day {
                                    selected = d
                                    // mock: cycle a mood each tap
                                    let next = nextMood(after: moodByDay[d.startOfDay])
                                    moodByDay[d.startOfDay] = next
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)

                    // selected info (optional)
                    if let sel = selected {
                        HStack {
                            Text(DateFormatter.medium.string(from: sel)).bold()
                            Text(moodByDay[sel.startOfDay]?.rawValue ?? "—")
                        }
                        .padding(.horizontal)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Mood Calendar")
        }
        .onAppear { seedMock() }
    }

    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: monthOffset, to: Date())!))!
    }
    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f.string(from: monthStart)
    }
    private var weekdaySymbols: [String] {
        let f = DateFormatter(); f.locale = .current; return f.shortWeekdaySymbols // SUN MON...
    }
    private var daysGrid: [Date?] {
        let firstWeekday = cal.component(.weekday, from: monthStart) // 1..7
        let leading = (firstWeekday + 6) % 7 // 0..6
        let days = cal.range(of: .day, in: .month, for: monthStart)!.count
        var arr = Array<Date?>(repeating: nil, count: leading)
        for i in 0..<days { arr.append(cal.date(byAdding: .day, value: i, to: monthStart)!) }
        return arr
    }
    private func nextMood(after current: Mood?) -> Mood {
        guard let c = current, let i = Mood.allCases.firstIndex(of: c) else { return .happy }
        return Mood.allCases[(i + 1) % Mood.allCases.count]
    }
    private func seedMock() {
        // mock: populate a few emoji for the current month
        moodByDay.removeAll()
        let sample: [(Int, Mood)] = [ (2,.sad), (3,.angry), (9,.sad), (11,.happy), (19,.happy), (20,.okay) ]
        for (day, mood) in sample {
            if let d = cal.date(byAdding: .day, value: day-1, to: monthStart) {
                moodByDay[d.startOfDay] = mood
            }
        }
    }
}

private struct DayCell: View {
    let date: Date?
    let selected: Date?
    let mood: Mood?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(date.map { String(Calendar.current.component(.day, from: $0)) } ?? "")
                    .font(.callout)
                    .foregroundStyle(date == nil ? .clear : .primary)
                Text(mood?.rawValue ?? " ")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue : .clear, lineWidth: 2)
                    )
            )
        }
        .disabled(date == nil)
    }

    private var isSelected: Bool {
        guard let d = date, let s = selected else { return false }
        return Calendar.current.isDate(d, inSameDayAs: s)
    }
}

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
private extension DateFormatter {
    static let medium: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; return f }()
}


#Preview {
    MoodCalendarView()
}
