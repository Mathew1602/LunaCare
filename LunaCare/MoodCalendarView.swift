//
//  MoodCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//

import SwiftUI
import FirebaseFirestore

struct MoodCalendarView: View {
    @EnvironmentObject var auth: AuthViewModel

    private let headerImageName = "moodCalendar"

    @State private var monthOffset = 0
    @State private var selected: Date? = nil
    @State private var moodByDay: [Date: Mood] = [:]
    @State private var noteByDay: [Date: String] = [:]

    private let cal = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible()), count: 7)
    
    @State private var loading = false
    @State private var errorText: String? = nil
    
    final class MoodCalendarRepository {
        func fetchMonth(uid: String, monthStart: Date) async throws -> [Date: (mood: Mood, note: String?)]{
            let cal = Calendar.current
            let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
            let ref = Firestore.firestore()
                .collection("users").document(uid)
                .collection("mood_logs")
                .whereField("createdAt", isGreaterThanOrEqualTo: monthStart)
                .whereField("createdAt", isLessThan: monthEnd)
                .order(by: "createdAt", descending: true)

            let snap = try await ref.getDocuments()
            var result: [Date: (mood: Mood, note: String?)] = [:]
            for d in snap.documents {
                guard let score = d["mood"] as? Int,
                      let ts = d["createdAt"] as? Timestamp else { continue }
                let note = d["notes"] as? String
                let day = cal.startOfDay(for: ts.dateValue())
                if result[day] == nil {
                    result[day] = (mapScore(score), note)
                }

            }
            return result
        }
        private func mapScore(_ s: Int) -> Mood {
            switch s { case 4: return .ecstatic; case 2: return .happy; case 0: return .okay; case -1: return .sad; case -2: return .angry; default: return .okay }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

//                    Text("Mood Calendar")
//                        .font(.title2).bold()
//                        .padding(.horizontal)

                    // header illustration
//                    Image(headerImageName)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(height: 300)
//                        .frame(maxWidth: .infinity)
//                        .clipped()
//                        .cornerRadius(18)
//                        .padding(.horizontal)

                    // month header
//                    HStack(spacing: 12) {
//                        Button { monthOffset -= 1; seedMock() } label: { Image(systemName: "chevron.left") }
//                        Spacer()
//                        Text(monthTitle).font(.headline)
//                        Spacer()
//                        Button { monthOffset += 1; seedMock() } label: { Image(systemName: "chevron.right") }
//                    }
//                    .padding(.horizontal)
                    HStack(spacing: 12) {
                        Button { monthOffset -= 1; Task { await loadMonth() } } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(monthTitle).font(.headline)
                        Spacer()
                        Button { monthOffset += 1; Task { await loadMonth() } } label: { Image(systemName: "chevron.right") }
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
                    
                    if loading { ProgressView().frame(maxWidth: .infinity) }

                    // days grid
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(daysGrid, id: \.self) { day in
                            DayCell(
                                date: day,
                                selected: selected,
                                //mood: moodByDay[day?.startOfDay ?? .distantPast]
                                mood: moodByDay[ day.map { Calendar.current.startOfDay(for: $0) } ?? .distantPast ]
                            ) {
                                if let d = day {
                                    selected = d
                                    // mock: cycle a mood each tap
//                                    let next = nextMood(after: moodByDay[d.startOfDay])
//                                    moodByDay[d.startOfDay] = next
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // selected info (optional)
//                    if let sel = selected {
//                        HStack {
//                            Text(DateFormatter.medium.string(from: sel)).bold()
//                            Text(moodByDay[sel.startOfDay]?.rawValue ?? "—")
//                        }
//                        .padding(.horizontal)
//                        .foregroundStyle(.secondary)
//                    }
                    if let sel = selected {
                        let dateText = DateFormatter.medium.string(from: sel)
                        let moodEmoji = moodByDay[sel.startOfDay]?.rawValue ?? ""
                        let noteText = noteByDay[sel.startOfDay] ?? ""
                        
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(dateText)
                                        .font(.headline)
                                        .bold()
                                    Spacer()
//                                    if !noteText.isEmpty {
//                                        Text("Note")
//                                            .font(.caption)
//                                            .fontWeight(.semibold)
//                                            .padding(.horizontal, 8)
//                                            .padding(.vertical, 4)
//                                            .background(Color(red: 249/255, green: 248/255, blue: 255/255))
//                                            .cornerRadius(8)
//                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    Text(moodEmoji)
                                        .font(.title3)
                                    if !noteText.isEmpty {
                                        Text(noteText)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    else {
                                           Text("No logs today")
                                               .font(.body)
                                               .foregroundColor(.secondary)
                                               .italic()
                                       }
                                }
                            }
                            
                            Spacer()
                            Image(systemName: "square.and.pencil")
                                .font(.title3)
                                .foregroundColor(Color(red: 139/255, green: 146/255, blue: 250/255))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 249/255, green: 248/255, blue: 255/255))
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Mood Calendar")
        }
        //.onAppear { seedMock() }
        .task { await loadMonth() }
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
//    private func seedMock() {
//        // mock: populate a few emoji for the current month
//        moodByDay.removeAll()
//        let sample: [(Int, Mood)] = [ (2,.sad), (3,.angry), (9,.sad), (11,.happy), (19,.happy), (20,.okay) ]
//        for (day, mood) in sample {
//            if let d = cal.date(byAdding: .day, value: day-1, to: monthStart) {
//                moodByDay[d.startOfDay] = mood
//            }
//        }
//    }
    private func loadMonth() async {
        guard !auth.uid.isEmpty else { return }
        loading = true; errorText = nil
        do {
            let map = try await MoodCalendarRepository().fetchMonth(uid: auth.uid, monthStart: monthStart)
            await MainActor.run {
                self.moodByDay = map.mapValues { $0.mood }
                self.noteByDay = map.compactMapValues { $0.note }
                self.loading = false
            }
        } catch {
            await MainActor.run { self.loading = false; self.errorText = "Failed to load: \(error.localizedDescription)" }
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
                    //.fill(Color(.secondarySystemBackground))
                    .fill(Color(red: 249/255, green: 248/255, blue: 255/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            //.stroke(isSelected ? Color.blue : .clear, lineWidth: 2)
                            .stroke(isSelected ? Color(red: 139/255, green: 146/255, blue: 250/255) : .clear, lineWidth: 2)

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
