//
//  CaregiverHomeViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import Foundation

/// State for the caregiver app: who they're linked to and that person's shared reports.
@MainActor
final class CaregiverHomeViewModel: ObservableObject {

    static let historyDays = 30

    @Published private(set) var mothers: [LinkedMother] = []
    @Published private(set) var selectedMother: LinkedMother? = nil
    @Published private(set) var reports: [DailyReport] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String? = nil

    private let repo: CaregiverReportRepository

    init(repo: CaregiverReportRepository = CaregiverReportRepository()) {
        self.repo = repo
    }

    var todayReport: DailyReport? {
        reports.first { Calendar.current.isDateInToday($0.day) }
    }

    /// Plain-language suggestions based on today's shared check-in.
    var helpTips: [String] {
        guard let today = todayReport else {
            return ["She hasn't checked in yet today. A simple \"How are you feeling?\" can go a long way."]
        }
        var tips: [String] = []
        if let mood = today.mood, mood.score < 0 {
            tips.append("Her mood is low today. Check in gently and listen without trying to fix things.")
        }
        let strong = Set(today.reportedSymptoms.filter { $0.level == .high }.map(\.name))
        if strong.contains("Sleep Trouble") || strong.contains("Fatigue") {
            tips.append("She's very tired. Offering to take a night feed or a nap shift could really help.")
        }
        if strong.contains("Appetite") {
            tips.append("Her appetite is low. Bringing an easy snack or meal can make a difference.")
        }
        return tips.isEmpty ? ["Things look steady today. Keep being there for her."] : tips
    }

    func load(caregiverUid: String) async {
        guard !caregiverUid.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            mothers = try await repo.fetchLinkedMothers(caregiverUid: caregiverUid)
            // Keep the current selection across refreshes, with its latest permissions.
            let current = mothers.first { $0.id == selectedMother?.id } ?? mothers.first
            selectedMother = current
            if let current {
                reports = try await repo.fetchReports(for: current, days: Self.historyDays)
            } else {
                reports = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ mother: LinkedMother) async {
        guard mother.id != selectedMother?.id else { return }
        selectedMother = mother
        reports = []
        isLoading = true
        defer { isLoading = false }

        do {
            reports = try await repo.fetchReports(for: mother, days: Self.historyDays)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
