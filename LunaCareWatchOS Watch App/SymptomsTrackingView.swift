//
//  SymptomsTrackingView.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI

struct SymptomsTrackingView: View {
    @State private var fatigue: Double = 0
    @State private var bleeding: Double = 0
    @State private var hairLoss: Double = 0
    @State private var appetite: Double = 0
    @State private var sleepTrouble: Double = 0

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
            }
            .padding(.vertical)
        }
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

            Slider(value: $value, in: 0...5, step: 1)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SymptomsTrackingView()
}
