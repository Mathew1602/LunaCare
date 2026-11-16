//
//  CaregiverAlertsView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

/// High-risk alerts for the selected mother, with what the caregiver can do about them.
struct CaregiverAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: CaregiverHomeViewModel

    var body: some View {
        NavigationStack {
            List {
                if let mother = vm.selectedMother {
                    alertsSection(for: mother)
                    if mother.permissions.riskAlerts {
                        howToHelpSection(for: mother)
                        DoctorContactsSection(mother: mother)
                    }
                }
                CrisisContactsSection()
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { vm.markAlertsSeen() }
        }
    }

    @ViewBuilder
    private func alertsSection(for mother: LinkedMother) -> some View {
        Section {
            if !mother.permissions.riskAlerts {
                Text("\(mother.name) hasn't turned on alerts for you.")
                    .foregroundColor(.secondary)
            } else if vm.alerts.isEmpty {
                Label("No alerts in the last \(CaregiverHomeViewModel.historyDays) days.", systemImage: "checkmark.circle")
                    .foregroundColor(.secondary)
            } else {
                ForEach(vm.alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Label("\(mother.name) may need extra support", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(alert.createdAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("Recent alerts")
        } footer: {
            if mother.permissions.riskAlerts {
                Text("LunaCare noticed patterns in \(mother.name)'s recent check-ins that are linked to a higher chance of postpartum depression. This is not a diagnosis.")
            }
        }
    }

    private func howToHelpSection(for mother: LinkedMother) -> some View {
        Section("What you can do") {
            Label("Check in gently: \"I've noticed you seem worn out lately. How are you really doing?\"",
                  systemImage: "bubble.left.and.bubble.right")
            Label("Listen without judging or trying to fix things. Let her know she's not alone.",
                  systemImage: "ear")
            Label("Take something off her plate today: a feed, a meal, or time to rest.",
                  systemImage: "hands.sparkles")
            Label("Encourage her to talk to her doctor, and offer to help make the call.",
                  systemImage: "stethoscope")
        }
    }
}
