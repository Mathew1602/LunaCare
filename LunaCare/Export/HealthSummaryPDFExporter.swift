import Foundation
import UIKit

enum HealthSummaryPDFExporter {
    private struct Line {
        let text: String
        let font: UIFont
        let color: UIColor
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func write(
        snapshot: HealthSummarySnapshot,
        includeMood: Bool,
        includeSymptoms: Bool,
        includeSleep: Bool,
        includeName: Bool,
        to directory: URL
    ) throws -> URL {
        let dateStamp = DateFormatter()
        dateStamp.dateFormat = "yyyyMMdd"
        let url = directory.appendingPathComponent("LunaCare_Appointment_Summary_\(dateStamp.string(from: Date())).pdf")
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        var lines = [
            Line(text: "LunaCare Appointment Summary", font: .boldSystemFont(ofSize: 22), color: .black)
        ]
        if includeName {
            lines.append(Line(text: snapshot.userName, font: .systemFont(ofSize: 13), color: .darkGray))
        }
        lines += [
            Line(
                text: "\(snapshot.period.rawValue): \(dateFormatter.string(from: snapshot.rangeFrom)) – \(dateFormatter.string(from: snapshot.rangeTo))",
                font: .systemFont(ofSize: 11),
                color: .darkGray
            ),
            Line(
                text: "Prepared \(dateFormatter.string(from: snapshot.generatedAt))",
                font: .systemFont(ofSize: 10),
                color: .darkGray
            ),
            Line(
                text: "This summary reflects recorded information and may be incomplete. It is not a diagnosis or medical assessment.",
                font: .systemFont(ofSize: 10),
                color: .darkGray
            ),
            Line(text: "", font: .systemFont(ofSize: 8), color: .black)
        ]

        if includeMood {
            lines.append(Line(text: "Mood check-ins", font: .boldSystemFont(ofSize: 15), color: .systemIndigo))
            lines.append(Line(
                text: "Recorded: \(snapshot.moodCount) (previous period: \(snapshot.previousMoodCount))",
                font: .systemFont(ofSize: 11),
                color: .black
            ))
            if snapshot.moodFrequencies.isEmpty {
                lines.append(Line(text: "No mood check-ins recorded in this period.", font: .systemFont(ofSize: 11), color: .darkGray))
            } else {
                lines += snapshot.moodFrequencies.map {
                    Line(text: "\($0.mood.rawValue) \($0.mood.label): \($0.count)", font: .systemFont(ofSize: 11), color: .black)
                }
            }
            lines.append(Line(text: "", font: .systemFont(ofSize: 8), color: .black))
        }

        if includeSymptoms {
            lines.append(Line(text: "Symptoms", font: .boldSystemFont(ofSize: 15), color: .systemIndigo))
            lines.append(Line(
                text: "Symptom logs: \(snapshot.symptomLogCount) (previous period: \(snapshot.previousSymptomLogCount))",
                font: .systemFont(ofSize: 11),
                color: .black
            ))
            if let current = snapshot.averageSymptomSeverity {
                let previous = snapshot.previousAverageSymptomSeverity.map { String(format: "%.1f", $0) } ?? "not available"
                lines.append(Line(
                    text: "Average reported severity: \(String(format: "%.1f", current))/10 (previous period: \(previous))",
                    font: .systemFont(ofSize: 11),
                    color: .black
                ))
            }
            if snapshot.topSymptoms.isEmpty {
                lines.append(Line(text: "No symptoms recorded in this period.", font: .systemFont(ofSize: 11), color: .darkGray))
            } else {
                lines += snapshot.topSymptoms.map {
                    Line(
                        text: "\($0.name): \($0.logCount) entries, average rating \(String(format: "%.1f", $0.averageSeverity))/10",
                        font: .systemFont(ofSize: 11),
                        color: .black
                    )
                }
            }
            lines.append(Line(text: "", font: .systemFont(ofSize: 8), color: .black))
        }

        if includeSleep {
            lines.append(Line(text: "Sleep (Apple Health)", font: .boldSystemFont(ofSize: 15), color: .systemIndigo))
            if let average = snapshot.averageSleepHours {
                lines.append(Line(
                    text: "Average recorded sleep: \(String(format: "%.1f", average)) hours across \(snapshot.sleepNightCount) nights.",
                    font: .systemFont(ofSize: 11),
                    color: .black
                ))
            } else {
                lines.append(Line(text: "No sleep data was available for this period.", font: .systemFont(ofSize: 11), color: .darkGray))
            }
        }

        try renderer.writePDF(to: url) { context in
            let margin: CGFloat = 42
            let contentWidth = pageRect.width - margin * 2
            let bottom = pageRect.height - margin
            var y = margin
            context.beginPage()

            for line in lines {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: line.font,
                    .foregroundColor: line.color
                ]
                let rect = (line.text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: attributes,
                    context: nil
                )
                let height = max(ceil(rect.height), 8)
                if y + height > bottom {
                    context.beginPage()
                    y = margin
                }
                (line.text as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: height),
                    withAttributes: attributes
                )
                y += height + 6
            }
        }
        return url
    }
}
