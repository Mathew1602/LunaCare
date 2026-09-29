//
//  DataExporter.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-09-27.
//

import Foundation
import UIKit

struct DataExporter {
    let health: [Measurement]?
    let moods: [CalendarDayLog]?
    let symptoms: [SymptomLogSummary]?
    let rangeFrom: Date
    let rangeTo: Date
    let userName: String

    static func makeExportDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LunaCareExport", isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let fileStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private func num(_ v: Double?, _ digits: Int = 1) -> String {
        guard let v else { return "" }
        return String(format: "%.\(digits)f", v)
    }

    private func num(_ v: Int?) -> String {
        v.map(String.init) ?? ""
    }

    private var healthColumns: [(title: String, value: (Measurement) -> String)] {
        [
            ("Date",                    { Self.dayFormatter.string(from: $0.createdAt) }),
            ("Steps",                   { num($0.steps) }),
            ("Distance (km)",           { num($0.distanceWalkedKm, 2) }),
            ("Flights Climbed",         { num($0.flightsClimbed, 0) }),
            ("Active Energy (kcal)",    { num($0.activeEnergyKcal, 0) }),
            ("Basal Energy (kcal)",     { num($0.basalEnergyKcal, 0) }),
            ("Exercise (min)",          { num($0.exerciseMinutes, 0) }),
            ("Stand (hrs)",             { num($0.standHours, 1) }),
            ("Avg Heart Rate (bpm)",    { num($0.avgHeartRateBpm, 0) }),
            ("Resting HR (bpm)",        { num($0.restingHRBpm, 0) }),
            ("Walking HR (bpm)",        { num($0.walkingHeartRateAvgBpm, 0) }),
            ("HRV SDNN (ms)",           { num($0.hrvSDNNms, 1) }),
            ("Respiratory Rate (bpm)",  { num($0.respiratoryRateBpm, 1) }),
            ("Blood Oxygen (%)",        { num($0.oxygenSaturationPct.map { $0 * 100 }, 1) }),
            ("VO2 Max (ml/kg/min)",     { num($0.vo2Max, 1) }),
            ("Sleep (hrs)",             { num($0.sleepHours, 2) }),
            ("Deep Sleep (hrs)",        { num($0.deepSleepHours, 2) }),
            ("REM Sleep (hrs)",         { num($0.remSleepHours, 2) }),
            ("Core Sleep (hrs)",        { num($0.coreSleepHours, 2) }),
            ("Sleep Efficiency (%)",    { num($0.sleepEfficiencyPct, 1) }),
            ("Awake After Sleep (min)", { num($0.wakeAfterSleepOnsetMin, 0) }),
            ("Weight (kg)",             { num($0.weightKg, 1) })
        ]
    }

    private var symptomNames: [String] {
        Set((symptoms ?? []).flatMap { $0.rows.map(\.name) }).sorted()
    }

    func writeCSVFiles(to dir: URL) throws -> [URL] {
        var urls: [URL] = []

        if let health {
            let cols = healthColumns
            var lines = [csvLine(cols.map(\.title))]
            lines += health.map { m in csvLine(cols.map { $0.value(m) }) }
            urls.append(try write(lines, name: "health_data.csv", in: dir))
        }

        if let moods {
            var lines = [csvLine(["Date/Time", "Mood", "Score", "Note"])]
            lines += moods.sorted { $0.createdAt < $1.createdAt }.map { log in
                csvLine([
                    Self.dateTimeFormatter.string(from: log.createdAt),
                    log.mood.label,
                    String(log.mood.score),
                    log.note ?? ""
                ])
            }
            urls.append(try write(lines, name: "mood_logs.csv", in: dir))
        }

        if let symptoms {
            let names = symptomNames
            var lines = [csvLine(["Date/Time"] + names)]
            lines += symptoms.sorted { $0.createdAt < $1.createdAt }.map { log in
                let values = Dictionary(log.rows.map { ($0.name, $0.value) },
                                        uniquingKeysWith: { first, _ in first })
                return csvLine([Self.dateTimeFormatter.string(from: log.createdAt)]
                               + names.map { values[$0].map(String.init) ?? "" })
            }
            urls.append(try write(lines, name: "symptom_logs.csv", in: dir))
        }

        return urls
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map { field in
            if field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }
        .joined(separator: ",")
    }

    private func write(_ lines: [String], name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func writePDF(to dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(
            "LunaCare_Report_\(Self.fileStampFormatter.string(from: Date())).pdf"
        )
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { ctx in
            var page = PDFPage(ctx: ctx, pageRect: pageRect)
            page.begin()

            page.drawText("LunaCare Health Report", font: .boldSystemFont(ofSize: 22))
            if !userName.isEmpty {
                page.drawText(userName, font: .systemFont(ofSize: 13))
            }
            page.drawText(
                "Period: \(Self.dayFormatter.string(from: rangeFrom)) to \(Self.dayFormatter.string(from: rangeTo))",
                font: .systemFont(ofSize: 11), color: .darkGray
            )
            page.drawText(
                "Generated: \(Self.dateTimeFormatter.string(from: Date()))",
                font: .systemFont(ofSize: 11), color: .darkGray
            )
            page.space(12)

            if let health {
                page.drawSection("Apple Health (daily)")
                let rows = health.map { m in
                    [
                        Self.dayFormatter.string(from: m.createdAt),
                        num(m.steps),
                        num(m.sleepHours, 1),
                        num(m.restingHRBpm, 0),
                        num(m.hrvSDNNms, 0),
                        num(m.activeEnergyKcal, 0),
                        num(m.exerciseMinutes, 0),
                        num(m.oxygenSaturationPct.map { $0 * 100 }, 0)
                    ]
                }
                page.drawTable(
                    headers: ["Date", "Steps", "Sleep h", "Rest HR", "HRV ms", "Active kcal", "Exercise m", "SpO2 %"],
                    widths: [0.16, 0.12, 0.11, 0.11, 0.11, 0.14, 0.13, 0.12],
                    rows: rows
                )
                page.space(16)
            }

            if let moods {
                page.drawSection("Mood Log")
                let rows = moods.sorted { $0.createdAt < $1.createdAt }.map { log in
                    [
                        Self.dateTimeFormatter.string(from: log.createdAt),
                        "\(log.mood.rawValue) \(log.mood.label)",
                        String(log.mood.score),
                        log.note ?? ""
                    ]
                }
                page.drawTable(
                    headers: ["Date/Time", "Mood", "Score", "Note"],
                    widths: [0.22, 0.18, 0.10, 0.50],
                    rows: rows
                )
                page.space(16)
            }

            if let symptoms {
                page.drawSection("Symptom Log")
                let rows = symptoms.sorted { $0.createdAt < $1.createdAt }.map { log in
                    [
                        Self.dateTimeFormatter.string(from: log.createdAt),
                        log.rows
                            .sorted { $0.name < $1.name }
                            .map { "\($0.name): \($0.value)" }
                            .joined(separator: ", ")
                    ]
                }
                page.drawTable(
                    headers: ["Date/Time", "Symptoms (1–10)"],
                    widths: [0.22, 0.78],
                    rows: rows
                )
            }
        }
        return url
    }
}

private struct PDFPage {
    let ctx: UIGraphicsPDFRendererContext
    let pageRect: CGRect
    let margin: CGFloat = 40
    var y: CGFloat = 0

    init(ctx: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        self.ctx = ctx
        self.pageRect = pageRect
    }

    private var contentWidth: CGFloat { pageRect.width - margin * 2 }
    private var bottom: CGFloat { pageRect.height - margin }

    mutating func begin() {
        ctx.beginPage()
        y = margin
    }

    mutating func space(_ h: CGFloat) { y += h }

    mutating func ensureRoom(_ h: CGFloat) {
        if y + h > bottom { begin() }
    }

    mutating func drawText(_ text: String, font: UIFont, color: UIColor = .black) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin, attributes: attrs, context: nil
        )
        ensureRoom(rect.height)
        (text as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: rect.height),
            withAttributes: attrs
        )
        y += ceil(rect.height) + 4
    }

    mutating func drawSection(_ title: String) {
        ensureRoom(60)
        drawText(title, font: .boldSystemFont(ofSize: 16), color: .systemIndigo)
    }

    mutating func drawTable(headers: [String], widths: [CGFloat], rows: [[String]]) {
        guard !rows.isEmpty else {
            drawText("No data for this period.", font: .italicSystemFont(ofSize: 11), color: .gray)
            return
        }

        let headerFont = UIFont.boldSystemFont(ofSize: 9)
        let cellFont = UIFont.systemFont(ofSize: 9)
        let padding: CGFloat = 3

        func rowHeight(_ cells: [String], font: UIFont) -> CGFloat {
            var h: CGFloat = 0
            for (i, cell) in cells.enumerated() {
                let w = contentWidth * widths[i] - padding * 2
                let r = (cell as NSString).boundingRect(
                    with: CGSize(width: w, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil
                )
                h = max(h, ceil(r.height))
            }
            return h + padding * 2
        }

        func drawRow(_ cells: [String], font: UIFont, fill: UIColor?, y: CGFloat, height: CGFloat) {
            if let fill {
                fill.setFill()
                UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: height))
            }
            var x = margin
            for (i, cell) in cells.enumerated() {
                let w = contentWidth * widths[i]
                (cell as NSString).draw(
                    in: CGRect(x: x + padding, y: y + padding, width: w - padding * 2, height: height - padding * 2),
                    withAttributes: [.font: font, .foregroundColor: UIColor.black]
                )
                x += w
            }
        }

        let headerHeight = rowHeight(headers, font: headerFont)
        let headerFill = UIColor.systemIndigo.withAlphaComponent(0.15)

        ensureRoom(headerHeight * 2)
        drawRow(headers, font: headerFont, fill: headerFill, y: y, height: headerHeight)
        y += headerHeight

        for (index, row) in rows.enumerated() {
            let h = rowHeight(row, font: cellFont)
            if y + h > bottom {
                begin()
                drawRow(headers, font: headerFont, fill: headerFill, y: y, height: headerHeight)
                y += headerHeight
            }
            let fill: UIColor? = index.isMultiple(of: 2) ? nil : UIColor(white: 0.95, alpha: 1)
            drawRow(row, font: cellFont, fill: fill, y: y, height: h)
            y += h
        }
    }
}
