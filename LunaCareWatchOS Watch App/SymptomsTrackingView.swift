//
//  SymptomsTrackingView.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI
import WatchKit

struct SymptomsTrackingView: View {
    @State private var fatigue: Double = 0
    @State private var bleeding: Double = 0
    @State private var hairLoss: Double = 0
    @State private var appetite: Double = 0
    @State private var sleepTrouble: Double = 0

    @State private var showingSavedAlert = false   // 👈 new

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Symptoms Tracking")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                SymptomSlider(title: "Fatigue", value: $fatigue)
                SymptomSlider(title: "Bleeding", value: $bleeding)
                SymptomSlider(title: "Hair Loss", value: $hairLoss)
                SymptomSlider(title: "Appetite", value: $appetite)
                SymptomSlider(title: "Sleep Trouble", value: $sleepTrouble)

                Button(action: {
                    sendSymptomLog()
                }) {
                    Text("Save & Sync")
                        .font(.body)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(40)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .padding(.vertical)
        }
        .alert("Symptoms Saved",
               isPresented: $showingSavedAlert,
               actions: {
                   Button("OK", role: .cancel) { }
               },
               message: {
                   Text("Your symptom check-in has been synced")
               })
    }

    private func sendSymptomLog() {
        let values: [String: Int] = [
            "Fatigue": Int(fatigue),
            "Bleeding": Int(bleeding),
            "Hair Loss": Int(hairLoss),
            "Appetite": Int(appetite),
            "Sleep Trouble": Int(sleepTrouble)
        ]

        let payload = SymptomLogPayload(
            values: values,
            notes: nil,
            tags: ["watch"],
            source: "watch"
        )

        WatchConnectivityManager.shared.send(payload, type: .symptomLog)

        // Haptic + alert
        WKInterfaceDevice.current().play(.success)
        showingSavedAlert = true

        // Reset sliders
        fatigue = 0
        bleeding = 0
        hairLoss = 0
        appetite = 0
        sleepTrouble = 0
    }
}

struct SymptomSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)

            Slider(value: $value, in: 0...10, step: 1)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SymptomsTrackingView()
}
