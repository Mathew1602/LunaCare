//
//  MoodCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//  Updated by Mathew to allow editing mood entries via the pencil button.
//  Updated to use explicit IDs for logs and a Bool-driven sheet so edit always works.
//  Updated by Xiaoya to add deleting function.
//

import SwiftUI


// =============================================================
// MARK: - Theme
// =============================================================

fileprivate enum MoodCalendarTheme {

    static let background = Color.dynamic(light: .white, dark: .black)

    static let card = Color.dynamic(
        light: .white,
        dark:  Color(red: 0.13, green: 0.13, blue: 0.14)
    )
    static let cardBorder = Color.dynamic(
        light: Color(red: 0.92, green: 0.92, blue: 0.93),
        dark:  Color(red: 0.22, green: 0.22, blue: 0.24)
    )
    static let field = Color.dynamic(
        light: Color(red: 0.96, green: 0.96, blue: 0.96),
        dark:  Color(red: 0.19, green: 0.19, blue: 0.21)
    )
    static let divider = Color.dynamic(
        light: Color(red: 0.94, green: 0.94, blue: 0.95),
        dark:  Color(red: 0.20, green: 0.20, blue: 0.22)
    )
    static let ink = Color.dynamic(
        light: Color(red: 0.10, green: 0.10, blue: 0.12),
        dark:  Color(red: 0.96, green: 0.96, blue: 0.94)
    )

    /// Text on top of pastel colours (always dark)
    static let onPastel = Color(red: 0.10, green: 0.10, blue: 0.12)

    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
    static let coralSoft = Color(red: 1.00, green: 0.68, blue: 0.64)

    /// Order matches Mood.allCases: Ecstatic, Happy, Okay, Sad, Angry.
    /// Light pastels: pills and log tiles.
    private static let pastels: [Color] = [
        Color(red: 0.93, green: 0.97, blue: 0.79),  // lime
        Color(red: 1.00, green: 0.92, blue: 0.87),  // peach
        Color(red: 0.87, green: 0.95, blue: 0.92),  // mint
        Color(red: 0.88, green: 0.92, blue: 0.99),  // sky
        Color(red: 1.00, green: 0.89, blue: 0.88)   // coral
    ]

    /// Deeper shades: calendar dots (need to be visible at 6pt).
    private static let dots: [Color] = [
        Color(red: 0.71, green: 0.85, blue: 0.23),  // lime
        Color(red: 1.00, green: 0.68, blue: 0.48),  // peach
        Color(red: 0.50, green: 0.80, blue: 0.70),  // mint
        Color(red: 0.50, green: 0.66, blue: 0.95),  // sky
        Color(red: 0.95, green: 0.45, blue: 0.42)   // coral
    ]

    private static func index(of mood: Mood) -> Int {
        Array(Mood.allCases).firstIndex(of: mood) ?? 0
    }

    static func pastel(for mood: Mood) -> Color {
        pastels[index(of: mood) % pastels.count]
    }

    static func dot(for mood: Mood) -> Color {
        dots[index(of: mood) % dots.count]
    }
}


fileprivate extension Color {

    static func dynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}


// =============================================================
// MARK: - Mood Calendar View
// =============================================================

struct MoodCalendarView: View {

    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = MoodCalendarViewModel()

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)


    var body: some View {

        Group {

            ScrollView {

                VStack(alignment: .leading, spacing: 0) {

                    monthHeader
                        .padding(.bottom, 14)

                    if !monthSummary.isEmpty {
                        summaryRow
                            .padding(.bottom, 18)
                    }

                    weekdayRow
                        .padding(.bottom, 6)

                    if vm.loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    calendarGrid

                    Rectangle()
                        .fill(MoodCalendarTheme.divider)
                        .frame(height: 1)
                        .padding(.vertical, 18)

                    selectedDaySection

                    errorSection
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(MoodCalendarTheme.background.ignoresSafeArea())
            .navigationTitle("Mood Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MoodCalendarTheme.background, for: .navigationBar)
        }


        // =========================================================
        // MARK: - Load Calendar
        // =========================================================

        .task {
            await vm.load(uid: auth.uid)
        }


        // =========================================================
        // MARK: - Edit Mood Sheet
        // =========================================================

        .sheet(
            isPresented: Binding(
                get: { vm.editingLog != nil },
                set: { isPresented in
                    if !isPresented {
                        vm.editingLog = nil
                    }
                }
            )
        ) {

            EditMoodSheet(
                mood:
                    $vm.editingMood,
                note:
                    $vm.editingNote,
                isSaving:
                    vm.isSavingEdit,
                errorText: vm.errorText,
                onSave: {
                    Task {
                        await vm.saveEdit(uid: auth.uid)
                    }
                },
                onCancel: {
                    vm.editingLog = nil
                }
            )
            .presentationDetents([.medium, .large])
        }


        // =========================================================
        // MARK: - Delete Confirmation
        // =========================================================

        .alert(
            "Delete Mood Entry?",
            isPresented: $vm.showingDeleteConfirmation
        ) {

            Button("Cancel", role: .cancel) {
                vm.logToDelete = nil
            }

            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteLog(uid: auth.uid)
                }
            }

        } message: {
            Text("This mood entry and its note will be permanently deleted.")
        }
    }


    // =============================================================
    // MARK: - Month Header
    // =============================================================

    private var monthHeader: some View {

        HStack {

            Text(vm.monthTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(MoodCalendarTheme.ink)

            Spacer()

            HStack(spacing: 8) {

                MonthArrowButton(systemImage: "chevron.left") {
                    Task { await vm.setMonth(delta: -1, uid: auth.uid) }
                }

                MonthArrowButton(systemImage: "chevron.right") {
                    Task { await vm.setMonth(delta: 1, uid: auth.uid) }
                }
            }
        }
        .padding(.horizontal, 4)
    }


    // =============================================================
    // MARK: - Month Summary
    // =============================================================

    /// Latest mood of each day in the visible month, counted per mood.
    private var monthSummary: [(mood: Mood, count: Int)] {

        var counts: [Mood: Int] = [:]

        for day in vm.daysGrid.compactMap({ $0 }) {
            if let mood = vm.latestMood(for: day) {
                counts[mood, default: 0] += 1
            }
        }

        return Mood.allCases.compactMap { mood in
            guard let count = counts[mood], count > 0 else { return nil }
            return (mood, count)
        }
    }

    private var summaryRow: some View {

        HStack(spacing: 8) {

            ForEach(monthSummary, id: \.mood) { item in

                HStack(spacing: 5) {
                    Text(item.mood.rawValue)
                    Text("\(item.count)")
                        .fontWeight(.semibold)
                }
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(MoodCalendarTheme.onPastel)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(MoodCalendarTheme.pastel(for: item.mood))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.mood.label): \(item.count) days")
            }
        }
    }


    // =============================================================
    // MARK: - Weekdays + Grid
    // =============================================================

    private var weekdayRow: some View {

        HStack(spacing: 0) {
            ForEach(Array(vm.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(String(symbol.prefix(1)))
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {

        LazyVGrid(columns: cols, spacing: 4) {

            ForEach(Array(vm.daysGrid.enumerated()), id: \.offset) { _, day in

                DayCell(
                    date: day,
                    selected: vm.selected,
                    mood: vm.latestMood(for: day)
                ) {
                    if let day {
                        vm.selected = day
                    }
                }
            }
        }
    }


    // =============================================================
    // MARK: - Selected Day
    // =============================================================

    @ViewBuilder
    private var selectedDaySection: some View {

        if let selectedDay = vm.selected {

            let logs = vm.logsForSelected()

            VStack(alignment: .leading, spacing: 12) {

                HStack(alignment: .firstTextBaseline) {

                    Text(selectedDay, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(MoodCalendarTheme.ink)

                    Spacer()

                    if !logs.isEmpty {
                        Text(logs.count == 1 ? "1 log" : "\(logs.count) logs")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)


                if logs.isEmpty {

                    Text("No mood logged on this day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)

                } else {

                    ForEach(logs, id: \.id) { log in
                        moodLogCard(log)
                    }
                }
            }
        }
    }


    // =============================================================
    // MARK: - Error
    // =============================================================

    @ViewBuilder
    private var errorSection: some View {

        if let error = vm.errorText {

            HStack(alignment: .top, spacing: 10) {

                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(MoodCalendarTheme.danger)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MoodCalendarTheme.coralSoft.opacity(0.18))
            )
        }
    }


    // =============================================================
    // MARK: - Mood Log Card
    // =============================================================

    @ViewBuilder
    private func moodLogCard(_ log: CalendarDayLog) -> some View {

        HStack(alignment: .center, spacing: 14) {

            // Mood emoji tile
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoodCalendarTheme.pastel(for: log.mood))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(log.mood.rawValue)
                        .font(.title2)
                )


            // Mood, time, note
            VStack(alignment: .leading, spacing: 3) {

                HStack(spacing: 5) {

                    Text(log.mood.label)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(MoodCalendarTheme.ink)

                    Text("· \(DateFormatter.timeShort.string(from: log.createdAt))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(displayNote(for: log))
                    .font(.subheadline)
                    .foregroundStyle(hasNote(log) ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }


            Spacer(minLength: 0)


            // Edit / Delete menu
            Menu {

                Button {
                    vm.beginEdit(log: log)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    vm.requestDelete(log: log)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(vm.isDeleting)

            } label: {

                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More options")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MoodCalendarTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(MoodCalendarTheme.cardBorder, lineWidth: 1)
        )
    }


    // =============================================================
    // MARK: - Note Display
    // =============================================================

    private func hasNote(_ log: CalendarDayLog) -> Bool {
        !(log.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    }

    private func displayNote(for log: CalendarDayLog) -> String {
        let note = log.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return note.isEmpty ? "No note" : note
    }
}


// =============================================================
// MARK: - Month Arrow Button
// =============================================================

private struct MonthArrowButton: View {

    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MoodCalendarTheme.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(MoodCalendarTheme.field))
        }
        .buttonStyle(.plain)
    }
}


// =============================================================
// MARK: - Calendar Day Cell
// =============================================================

private struct DayCell: View {

    let date: Date?
    let selected: Date?
    let mood: Mood?
    let onTap: () -> Void


    var body: some View {

        Button(action: onTap) {

            VStack(spacing: 5) {

                Text(dayText)
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(textColor)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(isSelected ? MoodCalendarTheme.ink : .clear)
                    )
                    .overlay(
                        Circle().strokeBorder(
                            isToday && !isSelected ? MoodCalendarTheme.ink : .clear,
                            lineWidth: 1.5
                        )
                    )

                Circle()
                    .fill(mood.map(MoodCalendarTheme.dot(for:)) ?? .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(accessibilityText)
    }


    private var textColor: Color {
        if date == nil { return .clear }
        return isSelected ? MoodCalendarTheme.background : MoodCalendarTheme.ink
    }

    private var isToday: Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var isSelected: Bool {
        guard let date, let selected else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selected)
    }

    private var dayText: String {
        guard let date else { return "" }
        return String(Calendar.current.component(.day, from: date))
    }

    private var accessibilityText: String {
        guard let date else { return "" }
        let day = date.formatted(.dateTime.month(.wide).day())
        if let mood { return "\(day), \(mood.label)" }
        return day
    }
}


// =============================================================
// MARK: - Edit Mood Sheet
// =============================================================

private struct EditMoodSheet: View {

    @Binding var mood: Mood
    @Binding var note: String

    let isSaving: Bool
    let errorText: String?

    let onSave: () -> Void
    let onCancel: () -> Void


    /// MoodPickerGrid uses an optional binding; adapt the non-optional one.
    private var optionalMood: Binding<Mood?> {
        Binding(
            get: { mood },
            set: { newValue in
                if let newValue { mood = newValue }
            }
        )
    }


    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(MoodCalendarTheme.danger)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(MoodCalendarTheme.danger.opacity(0.1))
                            )
                    }

                    // Mood
                    VStack(alignment: .leading, spacing: 14) {

                        Text("Mood")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(MoodCalendarTheme.ink)

                        MoodPickerGrid(selectedMood: optionalMood)
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 12) {

                        Text("Note")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(MoodCalendarTheme.ink)

                        TextField("Optional note", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(MoodCalendarTheme.field)
                            )
                    }
                }
                .padding(20)
            }
            .background(MoodCalendarTheme.background.ignoresSafeArea())

            .navigationTitle("Edit Mood")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(MoodCalendarTheme.ink)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

// =============================================================
// MARK: - Date Formatters
// =============================================================

private extension DateFormatter {

    static let timeShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}


// =============================================================
// MARK: - Preview
// =============================================================

#Preview {

    MoodCalendarView()
        .environmentObject(AuthViewModel.preview)
}
