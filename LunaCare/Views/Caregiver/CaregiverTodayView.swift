//
//  CaregiverTodayView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

struct CaregiverTodayView: View {
    @ObservedObject var vm: CaregiverHomeViewModel

    var body: some View {
        CaregiverTab(vm: vm, title: "Today") { mother in
            List {
                Section {
                    statusCard(for: mother)
                }

                DailyReportSections(report: vm.todayReport, mother: mother)

                Section("How you can help") {
                    ForEach(vm.helpTips, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func statusCard(for mother: LinkedMother) -> some View {
        let checkedIn = vm.todayReport != nil
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(mother.name)'s day")
                .font(.title3.bold())
            Text(Date(), format: .dateTime.weekday(.wide).month().day())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Label(checkedIn ? "Checked in today" : "No check-in yet today",
                  systemImage: checkedIn ? "checkmark.circle.fill" : "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(checkedIn ? .green : .orange)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}
