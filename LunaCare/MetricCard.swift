//
//  MetricCard.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//

import SwiftUI

struct MetricCard: View {
    var icon: String
    var value: String
    var label: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
            Text(value)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
