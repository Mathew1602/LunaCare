import Foundation

enum HealthSummaryPeriod: String, CaseIterable, Identifiable {
    case week = "Last 7 days"
    case month = "Last 30 days"

    var id: String { rawValue }
    var days: Int { self == .week ? 7 : 30 }
}

struct MoodFrequency: Identifiable {
    let mood: Mood
    let count: Int

    var id: String { mood.id }
}

struct SymptomSummaryItem: Identifiable {
    let name: String
    let logCount: Int
    let averageSeverity: Double

    var id: String { name }
}

struct HealthSummarySnapshot {
    let period: HealthSummaryPeriod
    let rangeFrom: Date
    let rangeTo: Date
    let generatedAt: Date
    let userName: String
    let moodCount: Int
    let previousMoodCount: Int
    let moodFrequencies: [MoodFrequency]
    let symptomLogCount: Int
    let previousSymptomLogCount: Int
    let averageSymptomSeverity: Double?
    let previousAverageSymptomSeverity: Double?
    let topSymptoms: [SymptomSummaryItem]
    let sleepNightCount: Int
    let averageSleepHours: Double?

    static func make(
        period: HealthSummaryPeriod,
        rangeFrom: Date,
        rangeTo: Date,
        userName: String,
        generatedAt: Date = Date(),
        moods: [CalendarDayLog],
        previousMoods: [CalendarDayLog],
        symptoms: [SymptomLogSummary],
        previousSymptoms: [SymptomLogSummary],
        health: [Measurement]
    ) -> HealthSummarySnapshot {
        let frequencies = Mood.allCases.compactMap { mood -> MoodFrequency? in
            let count = moods.filter { $0.mood == mood }.count
            return count > 0 ? MoodFrequency(mood: mood, count: count) : nil
        }

        func symptomValues(in logs: [SymptomLogSummary]) -> [Int] {
            logs.flatMap { $0.rows.map(\.value) }.filter { (1...10).contains($0) }
        }

        let currentValues = symptomValues(in: symptoms)
        let previousValues = symptomValues(in: previousSymptoms)
        let averageCurrent = currentValues.isEmpty
            ? nil
            : Double(currentValues.reduce(0, +)) / Double(currentValues.count)
        let averagePrevious = previousValues.isEmpty
            ? nil
            : Double(previousValues.reduce(0, +)) / Double(previousValues.count)

        var symptomTotals: [String: (count: Int, total: Int)] = [:]
        for log in symptoms {
            for row in log.rows {
                guard (1...10).contains(row.value) else { continue }
                var totals = symptomTotals[row.name, default: (count: 0, total: 0)]
                totals.count += 1
                totals.total += row.value
                symptomTotals[row.name] = totals
            }
        }

        let topSymptoms = symptomTotals.map { name, totals in
            SymptomSummaryItem(
                name: name,
                logCount: totals.count,
                averageSeverity: Double(totals.total) / Double(totals.count)
            )
        }
        .sorted {
            if $0.logCount != $1.logCount { return $0.logCount > $1.logCount }
            if $0.averageSeverity != $1.averageSeverity {
                return $0.averageSeverity > $1.averageSeverity
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        .prefix(5)

        let sleepValues = health.compactMap(\.sleepHours)
        let averageSleep = sleepValues.isEmpty
            ? nil
            : sleepValues.reduce(0, +) / Double(sleepValues.count)

        return HealthSummarySnapshot(
            period: period,
            rangeFrom: rangeFrom,
            rangeTo: rangeTo,
            generatedAt: generatedAt,
            userName: userName,
            moodCount: moods.count,
            previousMoodCount: previousMoods.count,
            moodFrequencies: frequencies,
            symptomLogCount: symptoms.count,
            previousSymptomLogCount: previousSymptoms.count,
            averageSymptomSeverity: averageCurrent,
            previousAverageSymptomSeverity: averagePrevious,
            topSymptoms: Array(topSymptoms),
            sleepNightCount: sleepValues.count,
            averageSleepHours: averageSleep
        )
    }
}
