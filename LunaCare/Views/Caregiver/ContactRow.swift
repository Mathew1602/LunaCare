//
//  ContactRow.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

/// A contact with call / email buttons.
struct ContactRow: View {
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
            if !phone.isEmpty, let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                Link(destination: url) { Image(systemName: "phone.fill") }
                    .buttonStyle(.bordered)
            }
            if !email.isEmpty, let url = URL(string: "mailto:\(email)") {
                Link(destination: url) { Image(systemName: "envelope.fill") }
                    .buttonStyle(.bordered)
            }
        }
    }
}

/// Crisis lines, always shown regardless of what the mother shared.
struct CrisisContactsSection: View {
    var body: some View {
        Section {
            ContactRow(title: "Emergency", subtitle: "Immediate danger", phone: "911")
            ContactRow(title: "Suicide Crisis Helpline", subtitle: "Call or text, 24/7", phone: "988")
            ContactRow(title: "Postpartum Support International", subtitle: "HelpLine", phone: "1-800-944-4773")
        } header: {
            Text("Crisis support")
        } footer: {
            Text("If she may be in danger, call 911 right away.")
        }
    }
}

/// The mother's shared doctors, or why they aren't shown.
struct DoctorContactsSection: View {
    let mother: LinkedMother

    var body: some View {
        Section("\(mother.name)'s care team") {
            if !mother.permissions.doctorContact {
                Text("\(mother.name) hasn't shared her doctor's contact. Crisis support is always available.")
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
