//
//  EditHealthMetricsView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-09-27.
//

import SwiftUI

struct EditHealthMetricsView: View {
    @ObservedObject var store: HomeMetricsStore
    let uid: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [HealthMetric]

    init(store: HomeMetricsStore, uid: String) {
        self.store = store
        self.uid = uid
        _draft = State(initialValue: store.selected)
    }

    private var isFull: Bool { draft.count >= HealthMetric.maxSelected }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draft) { metric in
                        HStack {
                            Image(systemName: metric.icon)
                                .frame(width: 28)
                                .foregroundColor(Color(.systemIndigo))
                            Text(metric.title)
                            Spacer()
                            Text(metric.formattedValue(from: AppleWatchDataStore.shared.latestMeasurement))
                                .foregroundColor(.secondary)
                        }
                        .deleteDisabled(draft.count == 1)
                    }
                    .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        guard draft.count > 1 else { return }
                        draft.remove(atOffsets: offsets)
                    }
                } header: {
                    HStack {
                        Text("Shown on Home")
                        Spacer()
                        Text("\(draft.count)/\(HealthMetric.maxSelected)")
                    }
                } footer: {
                    Text("At least one metric is required.")
                }

                ForEach(HealthMetric.categories, id: \.self) { category in
                    let available = HealthMetric.allCases.filter { $0.category == category && !draft.contains($0) }
                    if !available.isEmpty {
                        Section {
                            ForEach(available) { metric in
                                Button {
                                    draft.append(metric)
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(isFull ? .gray : .green)
                                        Image(systemName: metric.icon)
                                            .frame(width: 28)
                                        Text(metric.title)
                                    }
                                }
                                .disabled(isFull)
                            }
                        } header: {
                            Text(category)
                        } footer: {
                            if isFull {
                                Text("Maximum of \(HealthMetric.maxSelected) metrics.")
                            }
                        }
                    }
                }

                Section {
                    Button("Reset to Default") {
                        draft = HealthMetric.defaults
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Health Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.save(draft, uid: uid)
                        dismiss()
                    }
                }
            }
        }
        .tint(Color(.systemIndigo))
    }
}
