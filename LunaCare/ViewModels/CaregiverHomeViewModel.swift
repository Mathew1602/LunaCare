//
//  CaregiverHomeViewModel.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2026-11-16.
//

import Foundation

/// State for the caregiver app: who they're linked to and that person's shared reports and alerts.
@MainActor
final class CaregiverHomeViewModel: ObservableObject {

    static let historyDays = 30
    /// How long an alert keeps the banner on the Today tab.
    private static let bannerDays = 3

    @Published private(set) var mothers: [LinkedMother] = []
    @Published private(set) var selectedMother: LinkedMother? = nil
    @Published private(set) var reports: [DailyReport] = []
    @Published private(set) var alerts: [RiskAlert] = []
    @Published private(set) var lastSeenAlertDate: Date? = nil
    @Published private(set) var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isShowingAlerts = false

    private let reportRepo: CaregiverReportRepository
    private let alertRepo: RiskAlertRepository

    init(reportRepo: CaregiverReportRepository = CaregiverReportRepository(),
         alertRepo: RiskAlertRepository = RiskAlertRepository()) {
        self.reportRepo = reportRepo
        self.alertRepo = alertRepo
    }

    // MARK: - Derived state

    var todayReport: DailyReport? {
        reports.first { Calendar.current.isDateInToday($0.day) }
    }

    var unseenAlertCount: Int {
        alerts.filter { $0.createdAt > (lastSeenAlertDate ?? .distantPast) }.count
    }

    /// The latest alert, if recent enough to show on the Today tab.
    var recentAlert: RiskAlert? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.bannerDays, to: Date())!
        return alerts.first { $0.createdAt >= cutoff }
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

    // MARK: - Actions

    func load(caregiverUid: String) async {
        guard !caregiverUid.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            mothers = try await reportRepo.fetchLinkedMothers(caregiverUid: caregiverUid)
            // Keep the current selection across refreshes, with its latest permissions.
            selectedMother = mothers.first { $0.id == selectedMother?.id } ?? mothers.first
            try await loadData(for: selectedMother)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ mother: LinkedMother) async {
        guard mother.id != selectedMother?.id else { return }
        selectedMother = mother
        isLoading = true
        defer { isLoading = false }

        do {
            try await loadData(for: mother)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAlertsSeen() {
        guard let mother = selectedMother else { return }
        let now = Date()
        UserDefaults.standard.set(now, forKey: Self.seenKey(for: mother))
        lastSeenAlertDate = now
    }

    // MARK: - Private

    private func loadData(for mother: LinkedMother?) async throws {
        guard let mother else {
            reports = []
            alerts = []
            return
        }
        lastSeenAlertDate = UserDefaults.standard.object(forKey: Self.seenKey(for: mother)) as? Date

        async let reports = reportRepo.fetchReports(for: mother, days: Self.historyDays)
        async let alerts = mother.permissions.riskAlerts
            ? alertRepo.fetchAlerts(motherUid: mother.id, days: Self.historyDays) : []
        (self.reports, self.alerts) = try await (reports, alerts)
    }

    private static func seenKey(for mother: LinkedMother) -> String {
        "caregiver.lastSeenAlert.\(mother.id)"
    }
}
