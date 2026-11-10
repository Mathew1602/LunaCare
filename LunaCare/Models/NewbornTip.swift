//
//  NewbornTip.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-11-10.
//

import Foundation

struct TipSource: Identifiable, Hashable {
    let title: String
    let publisher: String
    let url: URL

    var id: String { url.absoluteString }
}

struct NewbornTip: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let body: String
    let sourceIDs: [String]
}

enum NewbornTipCategory: String, CaseIterable, Identifiable {
    case sleep = "Sleep"
    case feeding = "Feeding"
    case diapering = "Diapering"
    case milestones = "Milestones"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sleep: return "moon.zzz"
        case .feeding: return "drop"
        case .diapering: return "sparkles"
        case .milestones: return "figure.and.child.holdinghands"
        }
    }

    var summary: String {
        switch self {
        case .sleep: return "Safe sleep basics"
        case .feeding: return "Hunger cues and how much"
        case .diapering: return "What's normal, when to call"
        case .milestones: return "What to look for, 0–6 months"
        }
    }

    var tips: [NewbornTip] { NewbornTipLibrary.tips[self] ?? [] }

    var sources: [TipSource] {
        let ids = Set(tips.flatMap(\.sourceIDs))
        return NewbornTipLibrary.sources.filter { ids.contains($0.id) }
    }
}

enum NewbornTipLibrary {
    private static func source(_ title: String, _ publisher: String, _ url: String) -> TipSource {
        TipSource(title: title, publisher: publisher, url: URL(string: url)!)
    }

    static let aapSafeSleep = source(
        "Sleep-Related Infant Deaths: Updated 2022 Recommendations for Reducing Infant Deaths in the Sleep Environment. Pediatrics. 2022;150(1):e2022057990",
        "American Academy of Pediatrics",
        "https://doi.org/10.1542/peds.2022-057990"
    )
    static let safeToSleep = source(
        "Safe to Sleep Campaign",
        "NIH – Eunice Kennedy Shriver National Institute of Child Health and Human Development",
        "https://safetosleep.nichd.nih.gov/"
    )
    static let aapBreastfeeding = source(
        "Policy Statement: Breastfeeding and the Use of Human Milk. Pediatrics. 2022;150(1):e2022057988",
        "American Academy of Pediatrics",
        "https://doi.org/10.1542/peds.2022-057988"
    )
    static let whoBreastfeeding = source(
        "Breastfeeding",
        "World Health Organization",
        "https://www.who.int/health-topics/breastfeeding"
    )
    static let healthyChildren = source(
        "HealthyChildren.org – Baby (feeding, diapers, fever, development)",
        "American Academy of Pediatrics",
        "https://www.healthychildren.org/English/ages-stages/baby/Pages/default.aspx"
    )
    static let cdcMilestones = source(
        "Evidence-Informed Milestones for Developmental Surveillance Tools. Pediatrics. 2022;149(3):e2021052138",
        "CDC / American Academy of Pediatrics",
        "https://doi.org/10.1542/peds.2021-052138"
    )
    static let cdcActEarly = source(
        "Learn the Signs. Act Early.",
        "Centers for Disease Control and Prevention",
        "https://www.cdc.gov/ncbddd/actearly/index.html"
    )

    static let sources: [TipSource] = [
        aapSafeSleep, safeToSleep, aapBreastfeeding, whoBreastfeeding,
        healthyChildren, cdcMilestones, cdcActEarly
    ]

    static let tips: [NewbornTipCategory: [NewbornTip]] = [
        .sleep: [
            NewbornTip(
                title: "Back to sleep, every sleep",
                body: "Place baby on their back for every nap and at night until age 1. Once baby can roll both ways on their own, you don't need to reposition them.",
                sourceIDs: [aapSafeSleep.id, safeToSleep.id]
            ),
            NewbornTip(
                title: "Firm, flat, and bare",
                body: "Use a firm, flat, non-inclined surface with a fitted sheet only — no pillows, bumpers, blankets, or soft toys. Car seats, swings, and couches aren't safe for routine sleep.",
                sourceIDs: [aapSafeSleep.id]
            ),
            NewbornTip(
                title: "Room-share, don't bed-share",
                body: "Keeping baby's crib or bassinet in your room for at least the first 6 months lowers risk. Bed-sharing, especially on a sofa or armchair, raises it.",
                sourceIDs: [aapSafeSleep.id, safeToSleep.id]
            ),
            NewbornTip(
                title: "Other protective factors",
                body: "Breastfeeding, offering a pacifier at sleep time (once feeding is established), routine immunizations, and a smoke-free home all reduce the risk of sleep-related deaths. Avoid overheating.",
                sourceIDs: [aapSafeSleep.id]
            ),
            NewbornTip(
                title: "Newborn sleep is irregular",
                body: "Newborns sleep in short stretches around the clock and wake often to feed. Longer night sleep develops gradually over the first months.",
                sourceIDs: [healthyChildren.id]
            )
        ],
        .feeding: [
            NewbornTip(
                title: "Feed on cue",
                body: "Early hunger cues include rooting, sucking on hands, and lip smacking. Crying is a late cue. Most newborns feed 8–12 times in 24 hours.",
                sourceIDs: [aapBreastfeeding.id, healthyChildren.id]
            ),
            NewbornTip(
                title: "Human milk, if it works for you",
                body: "Exclusive breastfeeding is recommended for about the first 6 months, with continued breastfeeding as foods are added. Infant formula is a safe, complete alternative — fed babies thrive.",
                sourceIDs: [aapBreastfeeding.id, whoBreastfeeding.id]
            ),
            NewbornTip(
                title: "Vitamin D for breastfed babies",
                body: "Breastfed and partially breastfed infants should get a vitamin D supplement of 400 IU daily, starting in the first days of life.",
                sourceIDs: [aapBreastfeeding.id, healthyChildren.id]
            ),
            NewbornTip(
                title: "Prepare formula as directed",
                body: "Follow the label exactly for water-to-powder ratio. Never dilute or concentrate formula, and discard any left in the bottle after a feeding.",
                sourceIDs: [healthyChildren.id]
            ),
            NewbornTip(
                title: "Signs baby is getting enough",
                body: "Steady weight gain after the first week (most regain birth weight by about 2 weeks), regular wet diapers, and seeming content after feeds are reassuring signs.",
                sourceIDs: [healthyChildren.id, aapBreastfeeding.id]
            )
        ],
        .diapering: [
            NewbornTip(
                title: "Wet diaper count",
                body: "By about day 5–6, expect 6 or more wet diapers a day. Fewer wet diapers can signal baby isn't getting enough milk — check with your provider.",
                sourceIDs: [healthyChildren.id]
            ),
            NewbornTip(
                title: "Stool changes are normal",
                body: "Early stools are black and sticky (meconium), then turn green and, by about day 4–5, yellow and seedy for breastfed babies or tan for formula-fed babies.",
                sourceIDs: [healthyChildren.id]
            ),
            NewbornTip(
                title: "Call about pale or bloody stools",
                body: "White, pale gray, or clay-colored stools, or blood in the diaper, should be checked by a doctor promptly.",
                sourceIDs: [healthyChildren.id]
            ),
            NewbornTip(
                title: "Preventing diaper rash",
                body: "Change diapers often, let skin air-dry, and use a zinc oxide or petroleum barrier cream. See a provider if a rash doesn't improve in 2–3 days or has blisters.",
                sourceIDs: [healthyChildren.id]
            ),
            NewbornTip(
                title: "Fever under 3 months is urgent",
                body: "A rectal temperature of 38°C (100.4°F) or higher in a baby under 3 months needs immediate medical attention.",
                sourceIDs: [healthyChildren.id]
            )
        ],
        .milestones: [
            NewbornTip(
                title: "By 2 months",
                body: "Calms when spoken to or picked up, smiles when you talk or smile, makes cooing sounds, and holds head up when on tummy.",
                sourceIDs: [cdcMilestones.id, cdcActEarly.id]
            ),
            NewbornTip(
                title: "By 4 months",
                body: "Smiles on their own to get your attention, coos back when you talk, holds head steady without support, and brings hands to mouth.",
                sourceIDs: [cdcMilestones.id, cdcActEarly.id]
            ),
            NewbornTip(
                title: "By 6 months",
                body: "Laughs, knows familiar people, takes turns making sounds with you, rolls from tummy to back, and pushes up on straight arms during tummy time.",
                sourceIDs: [cdcMilestones.id, cdcActEarly.id]
            ),
            NewbornTip(
                title: "Tummy time, from day one",
                body: "Short, supervised tummy time while baby is awake builds neck and shoulder strength. Start with a few minutes a few times a day and build up.",
                sourceIDs: [healthyChildren.id, aapSafeSleep.id]
            ),
            NewbornTip(
                title: "Trust your instincts",
                body: "Every baby develops at their own pace. If you're concerned or baby loses skills they once had, talk to your provider — don't wait.",
                sourceIDs: [cdcActEarly.id]
            )
        ]
    ]
}
