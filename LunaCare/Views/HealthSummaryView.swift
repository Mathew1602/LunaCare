import SwiftUI
import UIKit

struct HealthSummaryView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = HealthSummaryViewModel()

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $viewModel.period) {
                    ForEach(HealthSummaryPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Summary period")
            }

            Section {
                Toggle(isOn: $viewModel.includeMood) {
                    Label("Mood check-ins", systemImage: "face.smiling")
                }
                Toggle(isOn: $viewModel.includeSymptoms) {
                    Label("Symptoms", systemImage: "cross.case")
                }
                Toggle(isOn: $viewModel.includeSleep) {
                    Label("Apple Health sleep", systemImage: "bed.double")
                }
                Toggle(isOn: $viewModel.includeName) {
                    Label("Include my name in the PDF", systemImage: "person")
                }
            } header: {
                Text("Choose what to include")
            }

            Section {
                Label {
                    Text("Your preview stays in LunaCare. Nothing is sent until you choose Export & Share and select a destination.")
                        .font(.footnote)
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.indigo)
                }
                .padding(.vertical, 4)
            }

            if viewModel.isLoading && viewModel.snapshot == nil {
                Section {
                    HStack {
                        ProgressView()
                        Text("Preparing your summary…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let warning = viewModel.sourceWarning {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if let snapshot = viewModel.snapshot {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Appointment-ready overview", systemImage: "doc.text.magnifyingglass")
                            .font(.headline)
                        Text("\(snapshot.period.rawValue) · \(snapshot.rangeFrom.formatted(date: .abbreviated, time: .omitted)) – \(snapshot.rangeTo.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Review the details below before exporting or sharing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if viewModel.includeMood {
                    SectionCard(title: "Mood check-ins", icon: "face.smiling") {
                        Text("Recorded: \(snapshot.moodCount) (previous period: \(snapshot.previousMoodCount))")
                            .font(.subheadline)
                        if snapshot.moodFrequencies.isEmpty {
                            Text("No mood check-ins recorded in this period.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.moodFrequencies) { item in
                                HStack {
                                    Text("\(item.mood.rawValue) \(item.mood.label)")
                                    Spacer()
                                    Text("\(item.count)")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }

                if viewModel.includeSymptoms {
                    SectionCard(title: "Symptoms", icon: "cross.case") {
                        Text("Logs: \(snapshot.symptomLogCount) (previous period: \(snapshot.previousSymptomLogCount))")
                            .font(.subheadline)
                        if let current = snapshot.averageSymptomSeverity {
                            let previous = snapshot.previousAverageSymptomSeverity
                                .map { "\(formatted($0))/10" } ?? "not available"
                            Text("Average reported rating: \(formatted(current))/10 (previous period: \(previous))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if snapshot.topSymptoms.isEmpty {
                            Text("No symptoms recorded in this period.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.topSymptoms) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(item.logCount) entries · average rating \(formatted(item.averageSeverity))/10")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if viewModel.includeSleep {
                    SectionCard(title: "Sleep from Apple Health", icon: "bed.double") {
                        if let average = snapshot.averageSleepHours {
                            Text("\(formatted(average)) hours average across \(snapshot.sleepNightCount) recorded nights.")
                                .font(.subheadline)
                        } else {
                            Text("No sleep data was available for this period.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("This is a summary of recorded information, not a medical assessment or diagnosis. Data may be incomplete; review it with your care team as needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: viewModel.export) {
                        HStack {
                            Spacer()
                            Label("Export & Share PDF", systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canExport)
                }
            }
        }
        .navigationTitle("Health Summary")
        .listStyle(.insetGrouped)
        .task(id: viewModel.period) {
            await viewModel.load(uid: auth.uid, userName: auth.displayName)
        }
        .refreshable {
            await viewModel.load(uid: auth.uid, userName: auth.displayName)
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.exportedURL {
                SummaryShareSheet(items: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Couldn't prepare summary", isPresented: Binding(
            get: { viewModel.errorText != nil },
            set: { if !$0 { viewModel.errorText = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorText ?? "")
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    private let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.headline)
                content
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SummaryShareSheet: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        HealthSummaryView()
            .environmentObject(AuthViewModel())
    }
}
