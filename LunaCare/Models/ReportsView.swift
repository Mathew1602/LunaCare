//
//  ReportsView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-10-19.
//

import Foundation
import SwiftUI

struct ReportsView: View {

    @EnvironmentObject var auth: AuthViewModel

    @State private var notes: [DoctorNote] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let repository = DoctorRepository()


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("Doctor Reports")
                        .font(.title2.bold())

                    Text(
                        "Notes and observations shared by your healthcare providers."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }


                // Cloud status
                HStack(spacing: 10) {
                    Image(systemName: "icloud")
                        .foregroundColor(Color(.systemIndigo))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Synced with LunaCare Cloud")
                            .font(.subheadline.bold())

                        Text(
                            "Doctor notes are loaded from your secure Firebase record."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            Color(.systemIndigo)
                                .opacity(0.08)
                        )
                )


                // Content
                if auth.uid.isEmpty {

                    messageCard(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: "Sign in required",
                        detail:
                            "Sign in to your LunaCare account to view doctor notes."
                    )

                } else if isLoading {

                    VStack(spacing: 12) {
                        ProgressView()

                        Text("Syncing doctor notes...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.top, 50)

                } else if let errorMessage {

                    messageCard(
                        icon: "exclamationmark.triangle",
                        title: "Unable to load reports",
                        detail: errorMessage
                    )

                } else if notes.isEmpty {

                    messageCard(
                        icon: "doc.text",
                        title: "No reports yet",
                        detail:
                            "Notes created by your healthcare providers will appear here."
                    )

                } else {

                    // Count
                    HStack {
                        Text("Doctor Notes")
                            .font(.headline)

                        Spacer()

                        Text(
                            "\(notes.count) \(notes.count == 1 ? "note" : "notes")"
                        )
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    }


                    // All notes
                    ForEach(notes) { note in
                        ReportNoteCard(
                            note: note
                        )
                    }
                }
            }
            .padding()
        }
        .background(
            Color(.systemGroupedBackground)
        )
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)

        // Load latest notes whenever page opens
        .task {
            await loadNotes()
        }

        // Pull down to sync again
        .refreshable {
            await loadNotes()
        }

        .toolbar {
            ToolbarItem(
                placement: .navigationBarTrailing
            ) {
                Button {
                    Task {
                        await loadNotes()
                    }
                } label: {
                    Image(
                        systemName:
                            "arrow.clockwise"
                    )
                }
            }
        }
    }


    // MARK: - Load notes from Firestore

    @MainActor
    private func loadNotes() async {

        guard !auth.uid.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {

            notes =
                try await repository
                    .fetchNotes(
                        uid: auth.uid
                    )

        } catch {

            print(
                "Doctor note sync error:",
                error
            )

            errorMessage =
                "Could not sync doctor notes. Please try again."
        }

        isLoading = false
    }


    // MARK: - Empty / error card

    private func messageCard(
        icon: String,
        title: String,
        detail: String
    ) -> some View {

        VStack(spacing: 10) {

            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(
                    .secondary
                )

            Text(title)
                .font(
                    .subheadline.bold()
                )

            Text(detail)
                .font(.footnote)
                .foregroundColor(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
        }
        .padding(24)
        .frame(
            maxWidth: .infinity
        )
        .background(
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                Color(
                    .secondarySystemGroupedBackground
                )
            )
        )
    }
}


// MARK: - Doctor Note Card

private struct ReportNoteCard: View {

    let note: DoctorNote

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            // Metric + date
            HStack {

                Label(
                    note.metricTitle,
                    systemImage:
                        note.metricIcon
                )
                .font(
                    .subheadline.bold()
                )
                .foregroundColor(
                    Color(.systemIndigo)
                )

                Spacer()

                Text(
                    note.createdAt,
                    format:
                        .dateTime
                        .month(.abbreviated)
                        .day()
                        .year()
                )
                .font(.caption)
                .foregroundColor(
                    .secondary
                )
            }


            // Note text
            Text(note.text)
                .font(.body)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )


            Divider()


            // Doctor
            HStack(spacing: 6) {

                Image(
                    systemName:
                        "stethoscope"
                )

                Text(
                    note.doctorName
                )

                Spacer()

                Text(
                    note.createdAt,
                    format:
                        .dateTime
                        .hour()
                        .minute()
                )
            }
            .font(.caption)
            .foregroundColor(
                .secondary
            )
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                Color(
                    .secondarySystemGroupedBackground
                )
            )
        )
    }
}
