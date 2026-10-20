//
//  SymptomCalendarView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-09.
//  Updated by Mathew to show per-time symptom logs for the selected day.
//

import SwiftUI


struct SymptomCalendarView: View {

    @EnvironmentObject var auth:
        AuthViewModel

    @StateObject private var vm =
        SymptomCalendarViewModel()


    private let cols =
        Array(
            repeating:
                GridItem(.flexible()),
            count: 7
        )


    private let symptomTint =
        Color(.systemIndigo)


    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    spacing: 0
                ) {

                    // MARK: - Calendar

                    VStack(
                        spacing: 12
                    ) {

                        Spacer()


                        // Month Header
                        HStack {

                            Button {

                                Task {

                                    await vm.changeMonth(
                                        by: -1,
                                        uid: auth.uid
                                    )
                                }

                            } label: {

                                Image(
                                    systemName:
                                        "chevron.left"
                                )
                                .foregroundColor(
                                    symptomTint
                                )
                                .font(
                                    .title3
                                )
                            }


                            Spacer()


                            Text(
                                vm.monthTitle
                            )
                            .font(
                                .headline
                            )


                            Spacer()


                            Button {

                                Task {

                                    await vm.changeMonth(
                                        by: 1,
                                        uid: auth.uid
                                    )
                                }

                            } label: {

                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .foregroundColor(
                                    symptomTint
                                )
                                .font(
                                    .title3
                                )
                            }
                        }
                        .padding(
                            .horizontal,
                            16
                        )


                        // Weekdays
                        HStack {

                            ForEach(
                                vm.weekdaySymbols,
                                id: \.self
                            ) { symbol in

                                Text(
                                    symbol
                                )
                                .font(
                                    .caption
                                )
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
                            24
                        )
                        .padding(
                            .top,
                            8
                        )


                        // Calendar
                        LazyVGrid(
                            columns: cols,
                            spacing: 10
                        ) {
                            ForEach(
                                Array(vm.daysGrid.enumerated()),
                                id: \.offset
                            ) { _, day in

                                SymptomDayCell(
                                    date: day,
                                    selected: vm.selected,
                                    hasSymptoms: vm.hasSymptoms(
                                        on: day
                                    ),
                                    isToday: vm.isToday(
                                        day
                                    ),
                                    tint: symptomTint
                                ) {

                                    if let day {

                                        Task {

                                            await vm.select(
                                                day: day,
                                                uid: auth.uid
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(
                            .horizontal,
                            24
                        )
                        .padding(
                            .top,
                            8
                        )
                    }


                    Spacer()
                        .frame(
                            height: 24
                        )


                    Divider()


                    // MARK: - Selected Day

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        Text(
                            vm.selectedTitle
                        )
                        .font(
                            .headline
                        )


                        if vm.loadingSelected {

                            HStack {

                                Spacer()

                                ProgressView()
                                    .tint(
                                        symptomTint
                                    )

                                Spacer()
                            }

                        } else if
                            vm.selectedEntries
                                .isEmpty {

                            Text(
                                "No symptom logs recorded for this day."
                            )
                            .font(
                                .subheadline
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        } else {

                            ForEach(
                                vm.selectedEntries
                            ) { entry in

                                SwipeToDeleteSymptomCard(
                                    entry:
                                        entry,
                                    tint:
                                        symptomTint,
                                    isDeleting:
                                        vm.deletingEntryId ==
                                        entry.id,
                                    onDelete: {

                                        vm.requestDelete(
                                            entry
                                        )
                                    }
                                )
                            }
                        }


                        Spacer()
                    }
                    .padding(
                        .horizontal,
                        24
                    )
                    .padding(
                        .top,
                        16
                    )
                }
                .task {

                    await vm.loadMonth(
                        for: auth.uid
                    )
                }
            }

            .navigationTitle(
                "Symptom Calendar"
            )
        }


        // MARK: - Delete Confirmation

        .alert(
            "Delete Symptom Entry?",
            isPresented:
                $vm.showingDeleteConfirmation
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) {

                vm.entryToDelete =
                    nil
            }


            Button(
                "Delete",
                role: .destructive
            ) {

                Task {

                    await vm
                        .deleteSelectedEntry(
                            uid: auth.uid
                        )
                }
            }

        } message: {

            Text(
                "This symptom record will be permanently deleted."
            )
        }


        .onDisappear {

            NotificationManager
                .shared
                .scheduleDemo(
                    after: 5
                )
        }
    }
}


// =============================================================
// MARK: - Swipe Delete Card
// =============================================================

private struct SwipeToDeleteSymptomCard: View {

    let entry: SymptomLogSummary
    let tint: Color
    let isDeleting: Bool
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    private let deleteWidth: CGFloat = 90


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
                            .font(.title2)

                        Text("Delete")
                            .font(.caption.bold())
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
            .background(Color.red)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )


            // =====================================================
            // Main card
            // =====================================================

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                HStack(spacing: 6) {

                    Image(systemName: "clock")
                        .foregroundColor(tint)

                    Text(
                        timeFormatter.string(
                            from: entry.createdAt
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)


                    Spacer()


                    Image(systemName: "chevron.left")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("Swipe")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }


                ForEach(entry.rows) { row in

                    HStack {

                        Text(row.name)

                        Spacer()

                        Text("\(row.value) / 10")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                Color(.secondarySystemBackground)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .stroke(
                    tint.opacity(0.15),
                    lineWidth: 1
                )
            )
            .offset(x: offset)
            .contentShape(Rectangle())

            // IMPORTANT:
            // When fully opened, stop this card from
            // blocking taps on the Delete button behind it.
            .allowsHitTesting(
                offset > -deleteWidth + 5
            )

            .highPriorityGesture(

                DragGesture(
                    minimumDistance: 10
                )

                .onChanged { value in

                    let horizontal =
                        value.translation.width

                    let vertical =
                        value.translation.height


                    guard abs(horizontal) >
                            abs(vertical)
                    else {
                        return
                    }


                    if horizontal < 0 {

                        offset =
                            max(
                                horizontal,
                                -deleteWidth
                            )
                    }
                }

                .onEnded { value in

                    withAnimation(
                        .easeOut(
                            duration: 0.2
                        )
                    ) {

                        if value.translation.width < -35 {

                            offset =
                                -deleteWidth

                        } else {

                            offset = 0
                        }
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }


    private var timeFormatter: DateFormatter {

        let formatter =
            DateFormatter()

        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter
    }
}

// =============================================================
// MARK: - Calendar Cell
// =============================================================

private struct SymptomDayCell:
    View {

    let date: Date?
    let selected: Date?
    let hasSymptoms: Bool
    let isToday: Bool
    let tint: Color
    let onTap: () -> Void


    var body: some View {

        Button(
            action: onTap
        ) {

            VStack(
                spacing: 4
            ) {

                ZStack {

                    if isToday {

                        Circle()
                            .fill(
                                tint
                            )
                            .frame(
                                width: 28,
                                height: 28
                            )
                    }


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
                    .foregroundStyle(
                        date == nil
                            ? .clear
                            : (
                                isToday
                                    ? Color.white
                                    : .primary
                            )
                    )
                }


                Circle()
                    .fill(
                        tint
                    )
                    .frame(
                        width: 5,
                        height: 5
                    )
                    .opacity(
                        hasSymptoms
                            ? 1
                            : 0
                    )
            }
            .frame(
                maxWidth:
                    .infinity,
                minHeight: 44
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
        .disabled(
            date == nil
        )
    }


    private var dayText:
        String {

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


#Preview {

    SymptomCalendarView()
        .environmentObject(
            AuthViewModel.preview
        )
}
