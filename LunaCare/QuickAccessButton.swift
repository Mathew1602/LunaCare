//
//  QuickAccessButton.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//

import SwiftUI

struct QuickAccessButton: View {
    var icon: String
    var title: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .foregroundColor(Color(.systemIndigo))
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemIndigo).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemIndigo).opacity(0.35), lineWidth: 1)
        }
    }
}
