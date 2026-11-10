//
//  NewbornTipsView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-11-10.
//

import SwiftUI

struct NewbornTipsView: View {
    var body: some View {
        List {
            Section {
                ForEach(NewbornTipCategory.allCases) { category in
                    NavigationLink {
                        NewbornTipDetailView(category: category)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.rawValue)
                                Text(category.summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(.systemIndigo))
                        }
                    }
                }
            } header: {
                Text("Topics")
            } footer: {
                Text("General information for your baby, based on published guidance. LunaCare's focus is your recovery — this isn't medical advice. Contact your baby's healthcare provider with any concerns.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Newborn Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NewbornTipDetailView: View {
    let category: NewbornTipCategory

    var body: some View {
        List {
            Section {
                ForEach(category.tips) { tip in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tip.title)
                            .font(.subheadline.weight(.semibold))
                        Text(tip.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(citationLabel(for: tip))
                            .font(.caption2)
                            .foregroundColor(Color(.systemIndigo))
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(Array(category.sources.enumerated()), id: \.element.id) { index, source in
                    Link(destination: source.url) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("[\(index + 1)]")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.publisher)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text(source.title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(Color(.systemIndigo))
                        }
                    }
                }
            } header: {
                Text("Sources")
            } footer: {
                Text("If you're feeling overwhelmed caring for your baby, it's okay to place them safely in their crib and take a moment for yourself. Your wellbeing matters too.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func citationLabel(for tip: NewbornTip) -> String {
        let numbers = category.sources.enumerated()
            .filter { tip.sourceIDs.contains($0.element.id) }
            .map { "[\($0.offset + 1)]" }
        return "Source " + numbers.joined(separator: " ")
    }
}

#Preview {
    NavigationStack {
        NewbornTipsView()
    }
}
