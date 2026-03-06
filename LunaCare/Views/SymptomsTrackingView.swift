//
//  SymptomsTrackingView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//
import SwiftUI

struct SymptomEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var value: Double  // 0...10
}

fileprivate func severityText(_ value: Double) -> String {
    switch Int(value) {
    case 0: return "None"
    case 1...3: return "Mild"
    case 4...6: return "Moderate"
    case 7...8: return "High"
    default: return "Severe"
    }
}

struct SymptomsTrackingView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = SymptomTrackingViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach($vm.symptoms) { $symptom in
                        SymptomCard(symptom: $symptom)
                    }

                    Button {
                        vm.save(uid: auth.uid)
                    } label: {
                        Text("Save Symptoms")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.top, 4)

                    if let status = vm.backendStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Symptoms Tracking")
        }
        .alert("Your symptoms have been saved", isPresented: $vm.showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let status = vm.backendStatus {
                Text(status)
            }
        }
    }
}

fileprivate struct SymptomCard: View {
    @Binding var symptom: SymptomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(symptom.name)
                    .font(.headline)
                Spacer()
                Text("\(Int(symptom.value))/10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Slider(value: $symptom.value, in: 0...10, step: 1)
                HStack {
                    Text("0")
                    Spacer()
                    Text("2")
                    Spacer()
                    Text("4")
                    Spacer()
                    Text("6")
                    Spacer()
                    Text("8")
                    Spacer()
                    Text("10")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Text(severityText(symptom.value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

#Preview {
    SymptomsTrackingView()
        .environmentObject(AuthViewModel())
}
