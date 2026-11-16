//
//  CaregiverSupportView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import SwiftUI

struct CaregiverSupportView: View {
    @ObservedObject var vm: CaregiverHomeViewModel

    var body: some View {
        NavigationStack {
            List {
                if let mother = vm.selectedMother {
                    DoctorContactsSection(mother: mother)
                }
                CrisisContactsSection()
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Support")
        }
    }
}
