//
//  DataExportView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-09-27.
//

import SwiftUI
import UIKit

struct DataExportView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env:  AppEnvironment
    @StateObject private var vm = DataExportViewModel()

    var body: some View {
        List {
            Section {
                Toggle(isOn: $vm.includeHealth) {
                    Label("Apple Health Data", systemImage: "heart.text.square")
                }
                Toggle(isOn: $vm.includeMood) {
                    Label("Mood Tracking", systemImage: "face.smiling")
                }
                Toggle(isOn: $vm.includeSymptoms) {
                    Label("Symptom Tracking", systemImage: "list.bullet.clipboard")
                }
            } header: {
                Text("Include")
            } footer: {
                Text("Mood and symptom data will be exported from \(vm.usesCloud(uid: auth.uid) ? "the cloud" : "this device"). Apple Health data requires Health access.")
            }

            Section(header: Text("Date Range")) {
                Picker("Range", selection: $vm.rangeOption) {
                    ForEach(DataExportViewModel.RangeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                if vm.rangeOption == .custom {
                    DatePicker("From", selection: $vm.customFrom, in: ...vm.customTo, displayedComponents: .date)
                    DatePicker("To", selection: $vm.customTo, in: vm.customFrom...Date(), displayedComponents: .date)
                }
            }

            Section {
                Picker("Format", selection: $vm.format) {
                    ForEach(DataExportViewModel.ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Format")
            } footer: {
                Text(vm.format == .csv
                     ? "Separate CSV files for health, mood and symptom data. Opens in Excel or Numbers."
                     : "A single PDF report with tables for each data type.")
            }

            Section {
                Button {
                    Task {
                        await vm.export(uid: auth.uid, userName: auth.displayName)
                    }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isExporting {
                            ProgressView()
                        } else {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!vm.canExport)

                if vm.isExporting {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: vm.progress)
                            .progressViewStyle(.linear)
                        Text(vm.statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if !vm.exportedURLs.isEmpty {
                    Button {
                        vm.showShareSheet = true
                    } label: {
                        Label("Share Last Export Again", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .navigationTitle("Data Export")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $vm.showShareSheet) {
            ShareSheet(items: vm.exportedURLs)
                .presentationDetents([.medium, .large])
        }
        .alert("Export Failed", isPresented: Binding(
            get: { vm.errorText != nil },
            set: { if !$0 { vm.errorText = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorText ?? "")
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DataExportView()
            .environmentObject(AuthViewModel())
            .environmentObject(AppEnvironment.shared)
    }
}
