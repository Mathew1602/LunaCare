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


struct MoodCalendarView: View {

    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = MoodCalendarViewModel()

    private let cols =
        Array(
            repeating: GridItem(.flexible()),
            count: 7
        )

    private let noteTint =
        Color(.systemIndigo)

    private let tileBG =
        Color(.secondarySystemBackground)


    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    // =====================================================
                    // MARK: - Month Header
                    // =====================================================

                    HStack(
                        spacing: 12
                    ) {

                        Button {

                            Task {
                                await vm.setMonth(
                                    delta: -1,
                                    uid: auth.uid
                                )
                            }

                        } label: {

                            Image(
                                systemName:
                                    "chevron.left"
                            )
                            .foregroundColor(
                                noteTint
                            )
                        }


                        Spacer()


                        Text(
                            vm.monthTitle
                        )
                        .font(.headline)


                        Spacer()


                        Button {

                            Task {
                                await vm.setMonth(
                                    delta: 1,
                                    uid: auth.uid
                                )
                            }

                        } label: {

                            Image(
                                systemName:
                                    "chevron.right"
                            )
                            .foregroundColor(
                                noteTint
                            )
                        }
                    }
                    .padding(
                        .horizontal,
                        20
                    )


                    // =====================================================
                    // MARK: - Weekday Titles
                    // =====================================================

                    HStack {

                        ForEach(
                            vm.weekdaySymbols,
                            id: \.self
                        ) { symbol in

                            Text(symbol)
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                                .frame(
                                    maxWidth:
                                        .infinity
                                )
                        }
                    }
                    .padding(
                        .horizontal,
                        20
                    )


                    // =====================================================
                    // MARK: - Loading
                    // =====================================================

                    if vm.loading {

                        ProgressView()
                            .frame(
                                maxWidth:
                                    .infinity
                            )
                            .padding()
                    }


                    // =====================================================
                    // MARK: - Calendar Grid
                    // =====================================================

                    LazyVGrid(
                        columns: cols,
                        spacing: 10
                    ) {

                        ForEach(
                            vm.daysGrid,
                            id: \.self
                        ) { day in

                            DayCell(
                                date: day,
                                selected:
                                    vm.selected,
                                mood:
                                    vm.latestMood(
                                        for: day
                                    )
                            ) {

                                if let day {

                                    vm.selected =
                                        day
                                }
                            }
                        }
                    }
                    .padding(
                        .horizontal,
                        10
                    )


                    Divider()


                    // =====================================================
                    // MARK: - Selected Day Details
                    // =====================================================

                    if let selectedDay =
                        vm.selected {

                        let dateText =
                            DateFormatter
                                .medium
                                .string(
                                    from:
                                        selectedDay
                                )

                        let logs =
                            vm.logsForSelected()


                        VStack(
                            alignment: .leading,
                            spacing: 12
                        ) {

                            Text(
                                dateText
                            )
                            .font(
                                .headline
                            )
                            .bold()
                            .padding(
                                .horizontal,
                                20
                            )


                            if logs.isEmpty {

                                HStack(
                                    spacing: 8
                                ) {

                                    Image(
                                        systemName:
                                            "face.smiling"
                                    )
                                    .foregroundColor(
                                        noteTint
                                            .opacity(
                                                0.6
                                            )
                                    )


                                    Text(
                                        "No mood logs today"
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                    .italic()
                                }
                                .padding(
                                    .horizontal,
                                    20
                                )

                            } else {

                                ForEach(
                                    logs,
                                    id: \.id
                                ) { log in

                                    moodLogCard(
                                        log
                                    )
                                }
                            }
                        }
                        .padding(
                            .vertical,
                            8
                        )
                    }


                    // =====================================================
                    // MARK: - Error
                    // =====================================================

                    if let error =
                        vm.errorText {

                        HStack(
                            alignment: .top,
                            spacing: 8
                        ) {

                            Image(
                                systemName:
                                    "exclamationmark.triangle"
                            )
                            .foregroundColor(
                                .red
                            )


                            Text(error)
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                        }
                        .padding(
                            .horizontal,
                            20
                        )
                    }
                }
                .padding(
                    .vertical,
                    8
                )
            }

            .navigationTitle(
                "Mood Calendar"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
        }


        // =========================================================
        // MARK: - Load Calendar
        // =========================================================

        .task {

            await vm.load(
                uid: auth.uid
            )
        }


        // =========================================================
        // MARK: - Edit Mood Sheet
        // =========================================================

        .sheet(
            isPresented:
                Binding(
                    get: {
                        vm.editingLog != nil
                    },
                    set: {
                        isPresented in

                        if !isPresented {
                            vm.editingLog =
                                nil
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
                onSave: {

                    Task {

                        await vm.saveEdit(
                            uid:
                                auth.uid
                        )
                    }
                },
                onCancel: {

                    vm.editingLog =
                        nil
                }
            )
        }


        // =========================================================
        // MARK: - Delete Confirmation
        // =========================================================

        .alert(
            "Delete Mood Entry?",
            isPresented:
                $vm.showingDeleteConfirmation
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) {

                vm.logToDelete =
                    nil
            }


            Button(
                "Delete",
                role: .destructive
            ) {

                Task {

                    await vm.deleteLog(
                        uid:
                            auth.uid
                    )
                }
            }

        } message: {

            Text(
                "This mood entry and its note will be permanently deleted."
            )
        }
    }


    // =============================================================
    // MARK: - Mood Log Card
    // =============================================================

    @ViewBuilder
    private func moodLogCard(
        _ log: CalendarDayLog
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {

            // Mood Emoji
            ZStack {

                Circle()
                    .fill(
                        noteTint
                            .opacity(0.10)
                    )
                    .frame(
                        width: 44,
                        height: 44
                    )


                Text(
                    log.mood.rawValue
                )
                .font(
                    .title2
                )
            }


            // Note + Time
            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(
                    displayNote(
                        for: log
                    )
                )
                .foregroundColor(
                    .primary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )


                HStack(
                    spacing: 5
                ) {

                    Image(
                        systemName:
                            "clock"
                    )


                    Text(
                        DateFormatter
                            .timeShort
                            .string(
                                from:
                                    log.createdAt
                            )
                    )
                }
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            // Edit + Delete
            HStack(
                spacing: 14
            ) {

                // Edit
                Button {

                    vm.beginEdit(
                        log: log
                    )

                } label: {

                    Image(
                        systemName:
                            "square.and.pencil"
                    )
                    .font(
                        .title3
                    )
                    .foregroundColor(
                        noteTint
                    )
                }


                // Delete
                Button {

                    vm.requestDelete(
                        log: log
                    )

                } label: {

                    Image(
                        systemName:
                            "trash"
                    )
                    .font(
                        .title3
                    )
                    .foregroundColor(
                        .red
                    )
                }
                .disabled(
                    vm.isDeleting
                )
            }
            .buttonStyle(
                .plain
            )
        }
        .padding(14)
        .background(

            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                tileBG
            )
        )
        .overlay(

            RoundedRectangle(
                cornerRadius: 16
            )
            .stroke(
                noteTint
                    .opacity(0.20),
                lineWidth: 1
            )
        )
        .shadow(
            color:
                .black
                    .opacity(0.04),
            radius: 4,
            x: 0,
            y: 2
        )
        .padding(
            .horizontal,
            20
        )
    }


    // =============================================================
    // MARK: - Note Display
    // =============================================================

    private func displayNote(
        for log: CalendarDayLog
    ) -> String {

        let note =
            log.note?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""


        return note.isEmpty
            ? "No note"
            : note
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

    private let accent =
        Color(.systemIndigo)


    var body: some View {

        Button(
            action: onTap
        ) {

            VStack(
                spacing: 2
            ) {

                ZStack {

                    // Today circle
                    if isToday {

                        Circle()
                            .fill(
                                accent
                            )
                            .frame(
                                width: 28,
                                height: 28
                            )
                    }


                    // Day number
                    Text(
                        dayText
                    )
                    .font(
                        .callout
                    )
                    .fontWeight(
                        isToday
                            ? .semibold
                            : .regular
                    )
                    .foregroundColor(
                        date == nil
                            ? .clear
                            : (
                                isToday
                                    ? .white
                                    : .primary
                            )
                    )
                }


                // Mood Emoji
                Text(
                    mood?.rawValue
                    ?? " "
                )
                .font(
                    .title3
                )
            }
            .frame(
                maxWidth:
                    .infinity,
                minHeight: 44
            )
            .padding(
                .vertical,
                6
            )
            .overlay(

                RoundedRectangle(
                    cornerRadius: 10
                )
                .stroke(
                    isSelected
                        ? accent
                        : .clear,
                    lineWidth: 2
                )
            )
        }
        .buttonStyle(
            .plain
        )
        .disabled(
            date == nil
        )
    }


    private var isToday: Bool {

        guard let date else {
            return false
        }

        return Calendar.current
            .isDateInToday(
                date
            )
    }


    private var isSelected: Bool {

        guard
            let date,
            let selected
        else {
            return false
        }


        return Calendar.current
            .isDate(
                date,
                inSameDayAs:
                    selected
            )
    }


    private var dayText: String {

        guard let date else {
            return ""
        }


        return String(
            Calendar.current
                .component(
                    .day,
                    from: date
                )
        )
    }
}


// =============================================================
// MARK: - Edit Mood Sheet
// =============================================================

private struct EditMoodSheet: View {

    @Binding var mood: Mood
    @Binding var note: String

    let isSaving: Bool

    let onSave: () -> Void
    let onCancel: () -> Void

    private let accent =
        Color(.systemIndigo)


    var body: some View {

        NavigationStack {

            Form {

                // Mood
                Section(
                    "Mood"
                ) {

                    Picker(
                        "Mood",
                        selection:
                            $mood
                    ) {

                        ForEach(
                            Mood.allCases
                        ) { moodOption in

                            HStack {

                                Text(
                                    moodOption
                                        .rawValue
                                )

                                Text(
                                    moodOption
                                        .label
                                )
                            }
                            .tag(
                                moodOption
                            )
                        }
                    }
                }


                // Note
                Section(
                    "Note"
                ) {

                    TextField(
                        "Optional note",
                        text:
                            $note,
                        axis:
                            .vertical
                    )
                    .lineLimit(
                        1...4
                    )
                }
            }

            .navigationTitle(
                "Edit Mood"
            )

            .navigationBarTitleDisplayMode(
                .inline
            )

            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "Cancel",
                        action:
                            onCancel
                    )
                }


                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button {

                        onSave()

                    } label: {

                        if isSaving {

                            ProgressView()

                        } else {

                            Text(
                                "Save"
                            )
                            .foregroundColor(
                                accent
                            )
                        }
                    }
                    .disabled(
                        isSaving
                    )
                }
            }
        }
    }
}


// =============================================================
// MARK: - Date Formatters
// =============================================================

private extension DateFormatter {

    static let medium:
        DateFormatter = {

            let formatter =
                DateFormatter()

            formatter.dateStyle =
                .medium

            return formatter
        }()


    static let timeShort:
        DateFormatter = {

            let formatter =
                DateFormatter()

            formatter.dateStyle =
                .none

            formatter.timeStyle =
                .short

            return formatter
        }()
}


// =============================================================
// MARK: - Preview
// =============================================================

#Preview {

    MoodCalendarView()
        .environmentObject(
            AuthViewModel.preview
        )
}
