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
                if let alert = vm.recentAlert {
                    Section { alertBanner(alert, for: mother) }
                }

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

    private func alertBanner(_ alert: RiskAlert, for mother: LinkedMother) -> some View {
        Button { vm.isShowingAlerts = true } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(mother.name) may need extra support")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(alert.createdAt, format: .relative(presentation: .named))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("See how to help")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.red.opacity(0.12))
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
