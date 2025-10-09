//
//  QuickAccessButton.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-10-09.
//

import SwiftUICore

struct QuickAccessButton: View {
    var icon: String
    var title: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
