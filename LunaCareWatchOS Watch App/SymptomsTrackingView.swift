//
//  SymptomsTrackingView.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI

struct SymptomsTrackingView: View {
    @State private var fatigue = false
    @State private var bleeding = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Symptoms Tracking")
                .font(.headline)
            
            Toggle("Fatigue", isOn: $fatigue)
            Toggle("Bleeding", isOn: $bleeding)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SymptomsTrackingView()
}
