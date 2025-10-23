//
//  SymptomCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//

import SwiftUI

import SwiftUI

// MARK: - Symptom “mark” shown on the calendar
enum SymptomMark: CaseIterable, Identifiable, Codable, Hashable {
    case pain, nausea, fever, fatigue, none

    var id: Self { self }

    var icon: String {
        switch self {
        case .pain:    return "bandage"       // SF Symbol
        case .nausea:  return "pills"
        case .fever:   return "thermometer"
        case .fatigue: return "bed.double"
        case .none:    return "checkmark"
        }
    }

    var color: Color {
        switch self {
        case .pain:    return .red
        case .nausea:  return .pink
        case .fever:   return .orange
        case .fatigue: return .green
        case .none:    return .blue
        }
    }

    var label: String {
        switch self {
        case .pain:    return "Pain"
        case .nausea:  return "Nausea"
        case .fever:   return "Fever"
        case .fatigue: return "Fatigue"
        case .none:    return "OK"
        }
    }
}

// MARK: - View
struct SymptomCalendarView: View {
    private let headerImageName = "sympCalendar"   // <-- add this image to Assets

    @State private var monthOffset = 0
    @State private var selected: Date? = nil
    @State private var markByDay: [Date: SymptomMark] = [:]   // MOCK (no DB)

    private let cal = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
//                    Text("Symptom Calendar")
//                        .font(.title2).bold()
//                        .padding(.horizontal)

                    // Header illustration
                    Image(headerImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)                 // adjust height to taste
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(18)
                        .padding(.horizontal)

                    // Month header
                    HStack(spacing: 12) {
                        Button {
                            monthOffset -= 1
                            seedMock()
                        } label: { Image(systemName: "chevron.left") }

                        Spacer()
                        Text(monthTitle).font(.headline)
                        Spacer()

                        Button {
                            monthOffset += 1
                            seedMock()
                        } label: { Image(systemName: "chevron.right") }
                    }
                    .padding(.horizontal)

                    // Weekday row
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { s in
                            Text(s).font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)

                    // Calendar grid
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(daysGrid, id: \.self) { day in
                            SymptomDayCell(
                                date: day,
                                selected: selected,
                                mark: markByDay[day?.startOfDay ?? .distantPast]
                            ) {
//                                if let d = day {
//                                    selected = d
//                                    // MOCK: cycle through marks on tap
//                                    let all = SymptomMark.allCases
//                                    let current = markByDay[d.startOfDay]
//
//                                    let next: SymptomMark = {
//                                        guard let cur = current, let i = all.firstIndex(of: cur) else { return .pain }
//                                        return all[(i + 1) % all.count]
//                                    }()
//
//                                    markByDay[d.startOfDay] = next
//                                }

                            }
                        }
                    }
                    .padding(.horizontal, 8)

//                    // Legend
//                    LegendView()
//                        .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Symptom Calendar")
        }
        .onAppear {
            seedMock()
            
            // display user notification
            NotificationManager.shared.scheduleDemo(after: 5)
        }
        
    }

    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: monthOffset, to: Date())!))!
    }
    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f.string(from: monthStart)
    }
    private var weekdaySymbols: [String] {
        let f = DateFormatter(); f.locale = .current; return f.shortWeekdaySymbols
    }
    private var daysGrid: [Date?] {
        let first = cal.component(.weekday, from: monthStart)   // 1..7
        let leading = (first + 6) % 7                           // 0..6
        let days = cal.range(of: .day, in: .month, for: monthStart)!.count
        var arr = Array<Date?>(repeating: nil, count: leading)
        for i in 0..<days { arr.append(cal.date(byAdding: .day, value: i, to: monthStart)!) }
        return arr
    }

    private func seedMock() {
        // mock colored icon marks for current visible month
        markByDay.removeAll()
        let sample: [(Int, SymptomMark)] = [
            (2, .pain), (7, .nausea), (8, .pain), (9, .fever),
            (11, .fatigue), (16, .pain), (17, .nausea), (20, .none)
        ]
        for (d, m) in sample {
            if let date = cal.date(byAdding: .day, value: d-1, to: monthStart) {
                markByDay[date.startOfDay] = m
            }
        }
    }
}

private struct SymptomDayCell: View {
    let date: Date?
    let selected: Date?
    let mark: SymptomMark?
    let onTap: () -> Void

    func hash(into hasher: inout Hasher) {
        hasher.combine(date?.timeIntervalSince1970 ?? -1)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(dayText)
                    .font(.callout)
                    .foregroundStyle(date == nil ? .clear : .primary)

                ZStack {
                    Circle()
                        .fill((mark?.color ?? Color(.tertiarySystemFill)).opacity(mark == nil ? 0.4 : 0.9))
                        .frame(width: 26, height: 26)

                    if let mark {
                        Image(systemName: mark.icon)
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
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

    private var dayText: String {
        guard let d = date else { return "" }
        return String(Calendar.current.component(.day, from: d))
    }
    private var isSelected: Bool {
        guard let d = date, let s = selected else { return false }
        return Calendar.current.isDate(d, inSameDayAs: s)
    }
}

private struct LegendView: View {
    private let items: [SymptomMark] = [.pain, .nausea, .fever, .fatigue, .none]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { mark in
                HStack(spacing: 6) {
                    Circle().fill(mark.color).frame(width: 14, height: 14)
                    Image(systemName: mark.icon).font(.caption2)
                    Text(mark.label).font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            Spacer()
        }
    }
}

private extension Date { var startOfDay: Date { Calendar.current.startOfDay(for: self) } }

#Preview {
    SymptomCalendarView()
}
