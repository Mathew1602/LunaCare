//
//  SymptomCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//  Updated by Mathew to show per-time symptom logs for the selected day.
//  Updated by Xiaoya

import SwiftUI


// =============================================================
// MARK: - Theme
// =============================================================

fileprivate enum CalendarTheme {

    static let background = Color.dynamic(light: .white, dark: .black)

    static let card = Color.dynamic(
        light: .white,
        dark:  Color(red: 0.13, green: 0.13, blue: 0.14)
    )
    static let cardBorder = Color.dynamic(
        light: Color(red: 0.91, green: 0.91, blue: 0.91),
        dark:  Color(red: 0.22, green: 0.22, blue: 0.24)
    )
    static let field = Color.dynamic(
        light: Color(red: 0.96, green: 0.96, blue: 0.96),
        dark:  Color(red: 0.19, green: 0.19, blue: 0.21)
    )
    static let ink = Color.dynamic(
        light: Color(red: 0.10, green: 0.10, blue: 0.12),
        dark:  Color(red: 0.96, green: 0.96, blue: 0.94)
    )

    /// Text on top of pastel colours (always dark)
    static let onPastel = Color(red: 0.10, green: 0.10, blue: 0.12)

    static let mint   = Color(red: 0.76, green: 0.91, blue: 0.85)
    static let lime   = Color(red: 0.84, green: 0.94, blue: 0.47)
    static let peach  = Color(red: 1.00, green: 0.84, blue: 0.72)
    static let coral  = Color(red: 1.00, green: 0.62, blue: 0.58)
    static let lilac  = Color(red: 0.89, green: 0.78, blue: 0.97)
    static let delete = Color(red: 0.95, green: 0.36, blue: 0.36)

    /// Severity colour for a 0–10 value.
    static func severityTint(_ value: Double) -> Color {
        switch value {
        case ..<4:  return mint
        case ..<7:  return peach
        default:    return coral
        }
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
// MARK: - Symptom Calendar View
// =============================================================

struct SymptomCalendarView: View {

    @EnvironmentObject var auth: AuthViewModel

    @StateObject private var vm = SymptomCalendarViewModel()

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)


    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    calendarCard

                    selectedDaySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .task {
                    await vm.loadMonth(for: auth.uid)
                }
            }
            .background(CalendarTheme.background.ignoresSafeArea())
            .navigationTitle("Symptom Calendar")
            .toolbarBackground(CalendarTheme.background, for: .navigationBar)
        }


        // MARK: - Delete Confirmation

        .alert(
            "Delete Symptom Entry?",
            isPresented: $vm.showingDeleteConfirmation
        ) {

            Button("Cancel", role: .cancel) {
                vm.entryToDelete = nil
            }

            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteSelectedEntry(uid: auth.uid)
                }
            }

        } message: {
            Text("This symptom record will be permanently deleted.")
        }


        .onDisappear {
            NotificationManager.shared.scheduleDemo(after: 5)
        }
    }


    // =========================================================
    // MARK: - Calendar Card
    // =========================================================

    private var calendarCard: some View {

        VStack(spacing: 14) {

            // Month header
            HStack {

                MonthArrowButton(systemImage: "chevron.left") {
                    Task { await vm.changeMonth(by: -1, uid: auth.uid) }
                }

                Spacer()

                Text(vm.monthTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(CalendarTheme.ink)

                Spacer()

                MonthArrowButton(systemImage: "chevron.right") {
                    Task { await vm.changeMonth(by: 1, uid: auth.uid) }
                }
            }


            // Weekdays
            HStack(spacing: 0) {
                ForEach(vm.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }


            // Days
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(Array(vm.daysGrid.enumerated()), id: \.offset) { _, day in

                    SymptomDayCell(
                        date: day,
                        selected: vm.selected,
                        hasSymptoms: vm.hasSymptoms(on: day),
                        isToday: vm.isToday(day)
                    ) {
                        if let day {
                            Task { await vm.select(day: day, uid: auth.uid) }
                        }
                    }
                }
            }


            // Legend
            HStack(spacing: 16) {

                LegendItem(label: "Symptoms") {
                    Circle()
                        .fill(CalendarTheme.coral)
                        .frame(width: 6, height: 6)
                }

                LegendItem(label: "Today") {
                    Circle()
                        .strokeBorder(CalendarTheme.ink, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }

                LegendItem(label: "Selected") {
                    Circle()
                        .fill(CalendarTheme.lime)
                        .frame(width: 10, height: 10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CalendarTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(CalendarTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
    }


    // =========================================================
    // MARK: - Selected Day
    // =========================================================

    private var selectedDaySection: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text(vm.selectedTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(CalendarTheme.ink)

                Spacer()

                if !vm.loadingSelected && !vm.selectedEntries.isEmpty {
                    Text(
                        vm.selectedEntries.count == 1
                            ? "1 log"
                            : "\(vm.selectedEntries.count) logs"
                    )
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(CalendarTheme.field))
                }
            }
            .padding(.horizontal, 4)


            if vm.loadingSelected {

                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 24)

            } else if vm.selectedEntries.isEmpty {

                HStack(spacing: 12) {

                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(CalendarTheme.onPastel)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(CalendarTheme.mint))

                    Text("No symptom logs recorded for this day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(CalendarTheme.field)
                )

            } else {

                ForEach(vm.selectedEntries) { entry in

                    SwipeToDeleteSymptomCard(
                        entry: entry,
                        isDeleting: vm.deletingEntryId == entry.id,
                        onDelete: {
                            vm.requestDelete(entry)
                        }
                    )
                }
            }
        }
    }
}


// =============================================================
// MARK: - Small Components
// =============================================================

private struct MonthArrowButton: View {

    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CalendarTheme.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(CalendarTheme.field))
        }
        .buttonStyle(.plain)
    }
}


private struct LegendItem<Marker: View>: View {

    let label: String
    @ViewBuilder var marker: Marker

    var body: some View {
        HStack(spacing: 6) {
            marker
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}


// =============================================================
// MARK: - Swipe Delete Card
// =============================================================

private struct SwipeToDeleteSymptomCard: View {

    let entry: SymptomLogSummary
    let isDeleting: Bool
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    private let deleteWidth: CGFloat = 90

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()


    var body: some View {

        ZStack(alignment: .trailing) {

            // =====================================================
            // Delete button behind card
            // =====================================================

            Button {
                onDelete()
            } label: {

                VStack(spacing: 6) {

                    if isDeleting {

                        ProgressView()
                            .tint(.white)

                    } else {

                        Image(systemName: "trash.fill")
                            .font(.title3)

                        Text("Delete")
                            .font(.system(.caption, design: .rounded).bold())
                    }
                }
                .foregroundColor(.white)
                .frame(width: deleteWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .frame(width: deleteWidth)
            .frame(maxHeight: .infinity)
            .background(CalendarTheme.delete)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))


            // =====================================================
            // Main card
            // =====================================================

            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 8) {

                    Image(systemName: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CalendarTheme.onPastel)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(CalendarTheme.lilac))

                    Text(Self.timeFormatter.string(from: entry.createdAt))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(CalendarTheme.ink)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Text("Swipe")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }


                VStack(spacing: 8) {

                    ForEach(entry.rows) { row in

                        HStack {

                            Text(row.name)
                                .font(.subheadline)
                                .foregroundStyle(CalendarTheme.ink)

                            Spacer()

                            Text("\(row.value) / 10")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(CalendarTheme.onPastel)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(
                                        CalendarTheme.severityTint(Double(row.value))
                                    )
                                )
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CalendarTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(CalendarTheme.cardBorder, lineWidth: 1)
            )
            .offset(x: offset)
            .contentShape(Rectangle())

            // IMPORTANT:
            // When fully opened, stop this card from
            // blocking taps on the Delete button behind it.
            .allowsHitTesting(offset > -deleteWidth + 5)

            .highPriorityGesture(

                DragGesture(minimumDistance: 10)

                    .onChanged { value in

                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        guard abs(horizontal) > abs(vertical) else { return }

                        if horizontal < 0 {
                            offset = max(horizontal, -deleteWidth)
                        }
                    }

                    .onEnded { value in

                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = value.translation.width < -35 ? -deleteWidth : 0
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}


// =============================================================
// MARK: - Calendar Cell
// =============================================================

private struct SymptomDayCell: View {

    let date: Date?
    let selected: Date?
    let hasSymptoms: Bool
    let isToday: Bool
    let onTap: () -> Void


    var body: some View {

        Button(action: onTap) {

            VStack(spacing: 3) {

                Text(dayText)
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(isSelected || isToday ? .semibold : .regular)
                    .foregroundStyle(textColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(isSelected ? CalendarTheme.lime : .clear)
                    )
                    .overlay(
                        Circle().strokeBorder(
                            isToday && !isSelected ? CalendarTheme.ink : .clear,
                            lineWidth: 1.5
                        )
                    )

                Circle()
                    .fill(CalendarTheme.coral)
                    .frame(width: 5, height: 5)
                    .opacity(hasSymptoms && date != nil ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }


    private var isSelected: Bool {
        guard let date, let selected else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selected)
    }

    private var textColor: Color {
        if date == nil { return .clear }
        return isSelected ? CalendarTheme.onPastel : CalendarTheme.ink
    }

    private var dayText: String {
        guard let date else { return "" }
        return String(Calendar.current.component(.day, from: date))
    }
}


#Preview {

    SymptomCalendarView()
        .environmentObject(AuthViewModel.preview)
}
