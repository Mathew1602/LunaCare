//
//  CaregiverSupportView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

struct CaregiverSupportView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var vm: CaregiverHomeViewModel

    var body: some View {
        NavigationStack {
            List {
                if let mother = vm.selectedMother {
                    doctorSection(for: mother)
                }

                Section {
                    ContactRow(title: "Emergency", subtitle: "Immediate danger", phone: "911")
                    ContactRow(title: "Suicide Crisis Helpline", subtitle: "Call or text, 24/7", phone: "988")
                    ContactRow(title: "Postpartum Support International", subtitle: "HelpLine", phone: "1-800-944-4773")
                } header: {
                    Text("Crisis support")
                } footer: {
                    Text("If she may be in danger, call 911 right away.")
                }

                Section {
                    if !auth.email.isEmpty {
                        Text("Signed in as \(auth.email)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Support")
        }
    }

    @ViewBuilder
    private func doctorSection(for mother: LinkedMother) -> some View {
        Section("\(mother.name)'s care team") {
            if !mother.permissions.doctorContact {
                Text("\(mother.name) hasn't shared her doctor's contact. Crisis support is always available below.")
                    .foregroundColor(.secondary)
            } else if mother.doctorContacts.isEmpty {
                Text("No doctors shared yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(mother.doctorContacts) { doctor in
                    ContactRow(title: doctor.name, subtitle: doctor.specialty,
                               phone: doctor.phone, email: doctor.email)
                }
            }
        }
    }
}

private struct ContactRow: View {
    let title: String
    let subtitle: String
    let phone: String
    var email: String = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                }
            }
            Spacer()
            if let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })"), !phone.isEmpty {
                Link(destination: url) { Image(systemName: "phone.fill") }
                    .buttonStyle(.bordered)
            }
            if let url = URL(string: "mailto:\(email)"), !email.isEmpty {
                Link(destination: url) { Image(systemName: "envelope.fill") }
                    .buttonStyle(.bordered)
            }
        }
    }
}
