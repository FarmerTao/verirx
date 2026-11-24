import Foundation

public struct ExamDomainInfo: Codable, Identifiable, Hashable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let weight_pct: Double
}

public struct ExamTrack: Identifiable, Hashable {
    public var id: String { examCode }
    public let examCode: String
    public let displayName: String
    public let subtitle: String
    public let domains: [ExamDomainInfo]
    public let trademarkDisclaimer: String
    public let isActive: Bool
}

public struct SkillUnit: Identifiable, Hashable {
    public let id: String
    public let examCode: String
    public let unitOrder: Int
    public let title: String
    public let subtitle: String
    public let themeColor: String
    public let iconName: String
    public let focusType: String
    public let drugIds: [String]
}

public struct DrugStemItem: Identifiable, Hashable {
    public let id: String
    public let stem: String
    public let position: String
    public let drugClass: String
    public let clinicalPearl: String
    public let exampleDrugs: [String]
    public let trapNote: String
}

public struct SigDrillItem: Identifiable, Hashable {
    public let id: String
    public let rxShorthand: String
    public let correctTokens: [String]
    public let distractorTokens: [String]
    public let clinicalTip: String
}

public struct DrugItem: Identifiable, Hashable {
    public let id: String
    public let genericName: String
    public let brandNames: [String]
    public let tallManName: String?
    public let drugClass: String
    public let deaSchedule: String
    public let remsProgram: String?
    public let indicationsSummary: String
    public let mechanismSummary: String
    public let boxedWarning: String?
    public let keyAdverseEffects: String
    public let keyInteractions: String
    public let storageHandling: String
    public let isHighAlert: Bool
    public let fdaSplSetId: String
    public let dailymedUrl: String
}

public struct FlashcardItem: Identifiable, Hashable {
    public let id: String
    public let drugId: String?
    public let examCode: String
    public let domainCode: String
    public let cardType: String
    public let frontPrompt: String
    public let backAnswer: String
    public let backDetail: String
    public let citationLabel: String
    public let citationUrl: String
    public let isFreeTier: Bool
}

public struct ChoiceOption: Codable, Identifiable, Hashable {
    public let id: String
    public let text: String
    public let rationale: String
}

public struct QuestionItem: Identifiable, Hashable {
    public let id: String
    public let drugId: String?
    public let examCode: String
    public let domainCode: String
    public let questionType: String
    public let difficulty: Int
    public let stem: String
    public let choices: [ChoiceOption]
    public let correctChoiceId: String
    public let explanation: String
    public let fdaSplSetId: String?
    public let citationQuote: String
    public let citationUrl: String
    public let generatorSource: String
    public let isFreeTier: Bool
}

public struct MatchPair: Identifiable, Hashable {
    public let id: String
    public let left: String
    public let right: String
}

/// Duolingo-style micro-lesson exercise types
public enum LessonExercise: Identifiable, Hashable {
    case matchPairs(id: String, prompt: String, pairs: [MatchPair], pearl: String)
    case sigWordBank(drill: SigDrillItem)
    case stemSpotter(id: String, exampleDrug: String, stemItem: DrugStemItem, classChoices: [String])
    case bossQuestion(question: QuestionItem)

    public var id: String {
        switch self {
        case .matchPairs(let id, _, _, _): return id
        case .sigWordBank(let drill): return "sig-\(drill.id)"
        case .stemSpotter(let id, _, _, _): return id
        case .bossQuestion(let q): return "boss-\(q.id)"
        }
    }
}

public enum FSRSRating: Int, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    public var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
}

public struct FSRSCardState: Codable, Hashable {
    public let cardId: String
    public var stability: Double
    public var difficulty: Double
    public var reps: Int
    public var lapses: Int
    public var lastReview: Date?
    public var nextDue: Date

    public static func initial(cardId: String, now: Date = Date()) -> FSRSCardState {
        FSRSCardState(
            cardId: cardId,
            stability: 0,
            difficulty: 5.0,
            reps: 0,
            lapses: 0,
            lastReview: nil,
            nextDue: now
        )
    }
}

public struct QuestionAttempt: Codable, Hashable, Identifiable {
    public var id: String { "\(questionId)-\(timestamp.timeIntervalSince1970)" }
    public let questionId: String
    public let domainCode: String
    public let difficulty: Int
    public let selectedChoiceId: String
    public let isCorrect: Bool
    public let timestamp: Date
}
