//
//  MoodHistoryView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI

struct MoodHistoryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Symptoms the past 7 days")
                    .font(.headline)
                Text("April 7th: High Fatigue and lack of sleep")
                    .foregroundColor(.red)
                Text("April 8th: Very Low Sleep")
                    .foregroundColor(.orange)
                
                Divider().padding(.vertical)

                Text("Mood past 7 days")
                    .font(.headline)
                Text("April 7th: Feeling upset").foregroundColor(.red)
                Text("April 8th: Feeling down").foregroundColor(.orange)
                Text("April 9th: Feeling happy").foregroundColor(.green)
            }
            .padding()
        }
        .navigationTitle("Mood History")
    }
}

#Preview {
    MoodHistoryView()
}
