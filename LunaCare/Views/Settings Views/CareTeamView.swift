//
//  CareTeamView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-08.
//

import SwiftUI

private enum CareTeamTab: Hashable {
    case approved, pending, comments
}

struct CareTeamView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = CareTeamViewModel()
    @State private var tab: CareTeamTab = .approved
    @State private var doctorToDecline: Doctor? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                accessBanner
                tabPicker

                if vm.isLoading && vm.doctors.isEmpty && vm.pendingDoctors.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = vm.errorMessage {
                    messageCard(icon: "exclamationmark.triangle", title: "Couldn't load your care team", detail: error)
                } else {
                    switch tab {
                    case .approved: doctorsSection
                    case .pending: pendingSection
                    case .comments: commentsSection
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Care Team")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(uid: auth.uid) }
        .refreshable { await vm.load(uid: auth.uid) }
        .confirmationDialog(
            "Decline \(doctorToDecline?.displayName ?? "this doctor")?",
            isPresented: Binding(get: { doctorToDecline != nil }, set: { if !$0 { doctorToDecline = nil } }),
            titleVisibility: .visible
        ) {
            Button("Decline Request", role: .destructive) {
                guard let doctor = doctorToDecline else { return }
                Task { await vm.decline(doctor, uid: auth.uid) }
            }
        } message: {
            Text("They won't be able to view your LunaCare data.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { vm.actionError != nil }, set: { if !$0 { vm.actionError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.actionError ?? "")
        }
    }

    private var tabPicker: some View {
        Picker("Section", selection: $tab) {
            Text("Approved").tag(CareTeamTab.approved)
            Text(vm.pendingDoctors.isEmpty ? "Pending" : "Pending (\(vm.pendingDoctors.count))").tag(CareTeamTab.pending)
            Text("Comments").tag(CareTeamTab.comments)
        }
        .pickerStyle(.segmented)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Waiting for Approval", count: vm.pendingDoctors.count)
            if vm.pendingDoctors.isEmpty {
                messageCard(icon: "hourglass",
                            title: "No pending requests",
                            detail: "When a doctor requests access to your data, it will appear here for you to approve.")
            } else {
                ForEach(vm.pendingDoctors) { doctor in
                    DoctorCard(doctor: doctor, isPending: true) {
                        PendingActions(
                            isBusy: vm.inProgressDoctorIds.contains(doctor.id),
                            onApprove: { Task { await vm.approve(doctor, uid: auth.uid) } },
                            onDecline: { doctorToDecline = doctor }
                        )
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Doctor Profile & Access")
                .font(.title2.bold())
            Text("Authorized healthcare providers who can view your LunaCare data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var accessBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.title3)
                .foregroundColor(Color(.systemIndigo))
            VStack(alignment: .leading, spacing: 4) {
                Text("Authorized Doctor Access")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(.systemIndigo))
                Text("Only the doctors listed below can view the data you sync from LunaCare. It is stored in the cloud with protected access.")
                    .font(.footnote)
                    .foregroundColor(Color(.systemIndigo).opacity(0.85))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemIndigo).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemIndigo).opacity(0.2), lineWidth: 1)
        )
    }

    private var doctorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Approved Doctors", count: vm.doctors.count)
            if vm.doctors.isEmpty {
                messageCard(icon: "person.crop.circle.badge.questionmark",
                            title: "No approved doctors yet",
                            detail: "Doctors you approve will appear here.")
            } else {
                ForEach(vm.doctors) { DoctorCard(doctor: $0, isPending: false) { EmptyView() } }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Doctor Comments", count: vm.comments.count)
            if vm.comments.isEmpty {
                messageCard(icon: "text.bubble",
                            title: "No comments yet",
                            detail: "Notes your doctors leave on your stats will show up here.")
            } else {
                metricFilter
                ForEach(vm.filteredComments) { DoctorCommentCard(comment: $0) }
            }
        }
    }

    private var metricFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", metric: nil)
                ForEach(vm.commentMetrics, id: \.self) { metric in
                    let sample = vm.comments.first { $0.metric == metric }
                    filterChip(title: sample?.metricTitle ?? metric, metric: metric)
                }
            }
        }
    }

    private func filterChip(title: String, metric: String?) -> some View {
        let selected = vm.selectedMetric == metric
        return Button {
            vm.selectedMetric = metric
        } label: {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(selected ? Color(.systemIndigo) : Color(.secondarySystemGroupedBackground)))
                .foregroundColor(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func messageCard(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)
            Text(title).font(.subheadline.bold())
            Text(detail)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct DoctorCard<Actions: View>: View {
    let doctor: Doctor
    let isPending: Bool
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(Color(.systemIndigo))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(.systemIndigo).opacity(0.1)))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(doctor.displayName)
                            .font(.headline)
                        Label(isPending ? "Pending" : "Authorized",
                              systemImage: isPending ? "clock" : "checkmark.circle")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(isPending ? .orange : .green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill((isPending ? Color.orange : Color.green).opacity(0.12)))
                    }
                    Text(doctor.specialty)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                DoctorInfoRow(icon: "building.2", label: "Organization", value: doctor.organization)
                DoctorInfoRow(icon: "stethoscope", label: "Specialty", value: doctor.specialty)
                DoctorInfoRow(icon: "checkmark.seal", label: "CPSO Number", value: doctor.cpsoNumber)
                DoctorInfoRow(icon: "envelope", label: "Email", value: doctor.email)
                DoctorInfoRow(icon: "phone", label: "Contact", value: doctor.phone)
                DoctorInfoRow(icon: "lock", label: "Access Level", value: doctor.accessLevel)
            }
            .padding()

            actions()
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
    }
}

private struct PendingActions: View {
    let isBusy: Bool
    let onApprove: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button(role: .destructive, action: onDecline) {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onApprove) {
                    Group {
                        if isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Text("Approve")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemIndigo))
            }
            .disabled(isBusy)
            .padding()
        }
    }
}

private struct DoctorInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemGroupedBackground)))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value.isEmpty ? "—" : value)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

private struct DoctorCommentCard: View {
    let comment: DoctorComment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(comment.metricTitle, systemImage: comment.metricIcon)
                    .font(.subheadline.bold())
                    .foregroundColor(Color(.systemIndigo))
                Spacer()
                Text(comment.createdAt, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(comment.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                Text(comment.doctorName)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}
