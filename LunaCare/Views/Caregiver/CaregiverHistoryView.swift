//
//  CaregiverHistoryView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

struct CaregiverHistoryView: View {
    @ObservedObject var vm: CaregiverHomeViewModel

    var body: some View {
        CaregiverTab(vm: vm, title: "History") { mother in
            if vm.reports.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No check-ins yet",
                    systemImage: "calendar",
                    description: Text("\(mother.name)'s check-ins from the last \(CaregiverHomeViewModel.historyDays) days will appear here.")
                )
            } else {
                List(vm.reports) { report in
                    NavigationLink {
                        List { DailyReportSections(report: report, mother: mother) }
                            .listStyle(.insetGrouped)
                            .navigationTitle(report.day.formatted(.dateTime.month().day()))
                    } label: {
                        HistoryRow(report: report)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

private struct HistoryRow: View {
    let report: DailyReport

    private var symptomSummary: String {
        let names = report.reportedSymptoms.prefix(2).map(\.name)
        return names.isEmpty ? "No symptoms reported" : names.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(report.mood?.rawValue ?? "–")
                .font(.title)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(report.day, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.headline)
                Text(symptomSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
