//
//  RecommendationEngine.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-29.
//

import Foundation

enum RecommendationEngine {

    static let highPPDScoreThreshold = 0.90
    static let screeningRecommendationTitle = "Consider a supportive check-in"

    struct RecommendationItem: Identifiable, Codable {
        var id: String? // Firestore doc ID
        let title: String
        let subtitle: String
        let reason: String
        var timestamp: Date = Date()
    }

    static func build(
        from insights: [WeeklyInsight],
        ppdRiskScore: Double? = nil
    ) -> [RecommendationItem] {
        let trendIdeas = insights.compactMap { makeTrendIdea(for: $0) }
            .sorted { $0.priority < $1.priority }
        var items = Array(trendIdeas.prefix(6).map(\.item))

        if let ppdRiskScore, ppdRiskScore >= highPPDScoreThreshold {
            items.append(.init(
                id: "screening-support",
                title: screeningRecommendationTitle,
                subtitle: "If you have concerns about your mood or well-being, reach out to your healthcare provider.",
                reason: "The screening model returned a high raw score (\(Int((ppdRiskScore * 100).rounded()))%). This is not a diagnosis or a verified probability."
            ))
        }

        return items
    }

    private static func pctStr(_ value: Double) -> String {
        String(format: "%.1f%%", abs(value))
    }

    private static func makeTrendIdea(
        for insight: WeeklyInsight
    ) -> (priority: Int, item: RecommendationItem)? {
        guard insight.direction == "higher" || insight.direction == "lower" else {
            return nil
        }

        let name = insight.metric.lowercased()
        let adverse: Bool
        let priority: Int
        let title: String
        let subtitle: String

        switch name {
        case "sleep hours":
            adverse = insight.direction == "lower"
            priority = 2
            title = adverse ? "Make a little room for rest" : "Notice what’s helping your sleep"
            subtitle = adverse
                ? "If you can, ask for help with one small task so you have a little more room to rest."
                : "Keep the parts of your routine that feel restful and realistic for you."
        case "deep sleep hours":
            adverse = insight.direction == "lower"
            priority = 3
            title = "Keep deep-sleep estimates in context"
            subtitle = adverse
                ? "This estimate was lower than last week. Sleep-stage readings can vary, so focus on your overall rest rather than one number."
                : "Your recorded estimate increased. Sleep-stage readings can vary, so focus on your overall rest rather than one number."
        case "rem sleep hours":
            adverse = insight.direction == "lower"
            priority = 3
            title = "Put REM sleep estimates in perspective"
            subtitle = adverse
                ? "Your recorded estimate was lower. Wearable sleep-stage readings can vary, so notice how rested you feel rather than focusing on one number."
                : "Your recorded estimate increased. Wearable sleep-stage readings can vary, so notice how rested you feel rather than focusing on one number."
        case "core sleep hours":
            adverse = insight.direction == "lower"
            priority = 3
            title = "Look at your core-sleep trend gently"
            subtitle = adverse
                ? "This estimate was lower than last week. It can vary from night to night and doesn’t explain sleep quality on its own."
                : "This estimate was higher than last week. It can vary from night to night and doesn’t explain sleep quality on its own."
        case "sleep efficiency":
            adverse = insight.direction == "lower"
            priority = 3
            title = adverse ? "Try one small wind-down cue" : "Keep your bedtime routine simple"
            subtitle = adverse
                ? "Choose one realistic cue for tonight, like dimming the lights or setting out what you need for tomorrow."
                : "Notice which bedtime habits feel helpful, without adding pressure to your routine."
        case "sleep trouble":
            adverse = insight.direction == "higher"
            priority = 3
            title = adverse ? "Make bedtime feel a little gentler" : "Keep the wind-down that feels helpful"
            subtitle = adverse
                ? "Try a calming cue before bed if it feels doable; note anything that seems to make rest easier or harder."
                : "Your sleep-trouble check-ins eased; keep any small wind-down habit that feels supportive."
        case "wake after sleep onset":
            adverse = insight.direction == "higher"
            priority = 3
            title = adverse ? "Set yourself up for a gentler night" : "Notice what’s supporting your rest"
            subtitle = adverse
                ? "If waking at night is bothering you, note what you notice and bring persistent concerns to your care team."
                : "Your recorded wake-after-sleep trend improved; notice which routines feel comfortable to continue."
        case "mood score":
            adverse = insight.direction == "lower"
            priority = adverse ? 1 : 5
            title = adverse ? "Make space for support" : "Notice what lifts your mood"
            subtitle = adverse
                ? "Share how you’ve been feeling with someone you trust, or bring it up with your care team."
                : "If it feels useful, jot down the people or moments that felt supportive this week."
        case "fatigue", "bleeding", "hair loss", "appetite issues":
            adverse = insight.direction == "higher"
            priority = adverse ? 1 : 5
            title = adverse
                ? "Keep a gentle note about \(insight.metric)"
                : "Notice how \(insight.metric) is changing"
            subtitle = adverse
                ? "A short note about when it happens may help you discuss persistent or concerning changes with your care team."
                : "Your \(insight.metric) check-ins eased; keep tracking only if it feels useful to you."
        case "steps", "walking distance":
            adverse = insight.direction == "lower"
            priority = adverse ? 4 : 5
            title = adverse ? "Keep movement gentle and doable" : "Keep a comfortable movement rhythm"
            subtitle = adverse
                ? "If you feel up to it, try a short walk or stretch; rest is okay too."
                : "Your recorded movement increased; choose a pace that still feels comfortable."
        case "exercise minutes":
            adverse = insight.direction == "lower"
            priority = adverse ? 4 : 5
            title = adverse ? "Fit movement into small moments" : "Keep activity at a pace that works"
            subtitle = adverse
                ? "A few comfortable minutes at a time count; there’s no need to make up for missed activity."
                : "Your recorded exercise time increased; keep it sustainable and listen to your body."
        case "flights climbed":
            adverse = insight.direction == "lower"
            priority = 4
            title = adverse ? "Choose movement that fits your day" : "Keep your movement comfortable"
            subtitle = adverse
                ? "If it works for you, add a little comfortable movement to a routine you already have."
                : "Your recorded flights climbed increased; keep choosing movement that feels safe and comfortable."
        case "active energy":
            adverse = insight.direction == "lower"
            priority = 4
            title = adverse ? "Let activity fit your energy" : "Keep listening to your energy"
            subtitle = adverse
                ? "Try a brief, comfortable activity only if it feels right; rest is a valid choice too."
                : "Your recorded active energy increased; keep your pace comfortable rather than chasing a number."
        case "stand hours":
            adverse = insight.direction == "lower"
            priority = 4
            title = adverse ? "Add a comfortable change of position" : "Keep breaks comfortable"
            subtitle = adverse
                ? "If you’ve been sitting and feel up to it, a brief stretch or change of position may fit your day."
                : "Your recorded stand hours increased; keep taking breaks in a way that feels comfortable."
        case "heart rate variability":
            adverse = insight.direction == "lower"
            priority = adverse ? 2 : 5
            title = adverse ? "Make room for recovery" : "Notice what supports your recovery"
            subtitle = adverse
                ? "Take a gentler pace when you can and check in with how you feel; wearable trends aren’t a diagnosis."
                : "Your HRV trend rose; notice which routines feel restorative, without treating one reading as a health verdict."
        case "resting heart rate":
            adverse = insight.direction == "higher"
            priority = adverse ? 0 : 5
            title = adverse ? "Check in with how you’re feeling" : "Keep noticing your recovery"
            subtitle = adverse
                ? "Readings can vary. If this change continues, concerns you, or comes with feeling unwell, contact your healthcare provider."
                : "Your recorded resting heart rate decreased; keep using how you feel—not a single number—as your guide."
        case "average heart rate", "walking heart rate":
            adverse = insight.direction == "higher"
            priority = adverse ? 2 : 5
            title = name == "walking heart rate"
                ? (adverse ? "Review your walking heart-rate trend" : "Keep walks comfortable")
                : (adverse ? "Put this heart-rate change in context" : "Keep activity at a comfortable pace")
            subtitle = adverse
                ? "Activity and measurement conditions affect heart-rate readings. If the change persists or concerns you, ask your healthcare provider."
                : "Your recorded \(insight.metric) decreased; use how you feel to guide activity, not one wearable number."
        case "respiratory rate":
            adverse = insight.direction == "higher"
            priority = adverse ? 0 : 5
            title = adverse ? "Check in on this breathing trend" : "Keep an eye on how you feel"
            subtitle = adverse
                ? "Wearable readings can vary. If the change continues or you feel unwell, contact your healthcare provider."
                : "Your recorded respiratory-rate trend decreased; readings alone can’t tell us what caused a change."
        case "blood oxygen":
            adverse = insight.direction == "lower"
            priority = adverse ? 0 : 5
            title = adverse ? "Review your oxygen readings" : "Keep readings in perspective"
            subtitle = adverse
                ? "Check sensor fit and measurement conditions; if the pattern persists or you feel unwell, contact your provider."
                : "Your recorded trend increased; wearable readings can vary and aren’t a substitute for medical advice."
        case "vo2 max":
            adverse = insight.direction == "lower"
            priority = adverse ? 3 : 5
            title = adverse ? "Keep your activity comfortable" : "Notice your fitness trend"
            subtitle = adverse
                ? "This estimate can vary. Choose comfortable movement if appropriate for you, and discuss persistent concerns with your provider."
                : "Your recorded estimate increased; keep a sustainable routine without treating the number as a measure of your worth."
        default:
            return nil
        }

        let context = "Your \(insight.metric) was \(insight.direction) compared with last week (\(pctStr(insight.percentChange)))."
        return (
            priority,
            .init(
                id: "trend-\(name)",
                title: title,
                subtitle: subtitle,
                reason: context
            )
        )
    }

}
