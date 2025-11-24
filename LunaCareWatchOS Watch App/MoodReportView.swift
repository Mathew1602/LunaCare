//
//  MoodReportView.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI

struct MoodReportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mood Report")
                    .font(.headline)
                
                Text("• Overall mood seemed happy and positive this week")
                Text("• In good condition mentally and physically")
                Text("• Doing well with recovery")
            }
            .padding()

            NavigationLink("View Mood History", destination: MoodHistoryView())
                .buttonStyle(.bordered)
                .padding(.top)
        }
    }
}

#Preview {
    MoodReportView()
}
