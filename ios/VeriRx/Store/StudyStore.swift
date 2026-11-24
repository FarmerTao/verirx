import Foundation
import Observation

@Observable
public final class StudyStore {
    public private(set) var exams: [ExamTrack] = []
    public var selectedExamCode: String = "PTCE" {
        didSet { reloadExamContent() }
    }

    public private(set) var skillUnits: [SkillUnit] = []
    public private(set) var drugStems: [DrugStemItem] = []
    public private(set) var sigDrills: [SigDrillItem] = []
    public private(set) var drugs: [DrugItem] = []
    public private(set) var allFlashcards: [FlashcardItem] = []
    public private(set) var allQuestions: [QuestionItem] = []

    // Duolingo Gamification & FSRS State
    public private(set) var fsrsStates: [String: FSRSCardState] = [:]
    public private(set) var attempts: [QuestionAttempt] = []
    public private(set) var completedNodeIds: Set<String> = []
    public private(set) var totalXP: Int = 0
    public private(set) var todayXP: Int = 0
    public let dailyGoalXP: Int = 50
    public private(set) var streakDays: Int = 1
    public private(set) var streakFreezes: Int = 2
    public private(set) var lastStudyDayKey: String = ""

    public var examDate: Date {
        didSet { saveProgress() }
    }
    public var hasAcceptedDisclaimer: Bool {
        didSet { UserDefaults.standard.set(hasAcceptedDisclaimer, forKey: "verirx.accepted_disclaimer") }
    }
    /// Free-to-learn core path enabled by default (optional supporter/mock pass via StoreKit 2)
    public var isProUnlocked: Bool = true

    public let scheduler = FSRSScheduler(desiredRetention: 0.90)
    public let adaptiveEngine = AdaptiveQuizEngine()
    private let packDB: ContentPackDatabase
    private let progressFileURL: URL

    public init(packDB: ContentPackDatabase = ContentPackDatabase()) {
        self.packDB = packDB
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.progressFileURL = appSupport.appendingPathComponent("verirx_duolingo_progress_v2.json")

        self.hasAcceptedDisclaimer = UserDefaults.standard.bool(forKey: "verirx.accepted_disclaimer")
        self.examDate = Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()

        loadStaticCatalog()
        loadSavedProgress()
        refreshDailyRollover()
    }

    public var currentExam: ExamTrack? {
        exams.first { $0.examCode == selectedExamCode } ?? exams.first
    }

    public var dueFlashcards: [FlashcardItem] {
        let now = Date()
        return allFlashcards.filter { card in
            guard let st = fsrsStates[card.id] else { return true }
            return st.nextDue <= now
        }
    }

    public var daysUntilExam: Int {
        max(1, Int(ceil(examDate.timeIntervalSinceNow / 86_400.0)))
    }

    public var readinessScore: Int {
        adaptiveEngine.estimatedScaledScore(
            domains: currentExam?.domains ?? [],
            attempts: attempts
        )
    }

    public enum NodeState: Equatable {
        case completed
        case current
        case locked
    }

    public func nodeId(unit: SkillUnit, step: Int) -> String {
        "\(unit.id)-node-\(step)"
    }

    public func isNodeCompleted(unit: SkillUnit, step: Int) -> Bool {
        completedNodeIds.contains(nodeId(unit: unit, step: step))
    }

    /// Returns the ID of the single active next node along the linear path.
    public var currentFocusNodeId: String? {
        for unit in skillUnits.sorted(by: { $0.unitOrder < $1.unitOrder }) {
            for step in 1...3 {
                let id = nodeId(unit: unit, step: step)
                if !completedNodeIds.contains(id) {
                    return id
                }
            }
        }
        return nil
    }

    public func nodeState(unit: SkillUnit, step: Int) -> NodeState {
        let id = nodeId(unit: unit, step: step)
        if completedNodeIds.contains(id) {
            return .completed
        }
        if currentFocusNodeId == id {
            return .current
        }
        return .locked
    }

    public func unitCompletedCount(for unit: SkillUnit) -> Int {
        (1...3).filter { isNodeCompleted(unit: unit, step: $0) }.count
    }

    /// Builds a 5-to-6 exercise Duolingo micro-lesson mixing stems, brand-generic matching, Sig word-banks, and FDA Boss MCQs!
    public func buildDuolingoLesson(for unit: SkillUnit, step: Int) -> [LessonExercise] {
        var exercises: [LessonExercise] = []

        // 1. Tap-to-Match Pairs (Stems or Brand ↔ Generic)
        if unit.focusType == "stems" && drugStems.count >= 4 {
            let slice = Array(drugStems.shuffled().prefix(4))
            let pairs = slice.map { MatchPair(id: $0.id, left: $0.stem, right: $0.drugClass) }
            exercises.append(
                .matchPairs(
                    id: "match-stems-\(unit.id)-\(step)",
                    prompt: "Tap matching Drug Stems & Classes",
                    pairs: pairs,
                    pearl: slice.first?.trapNote ?? "Drug stems instantly reveal mechanism of action."
                )
            )
        } else {
            let unitDrugs = drugs.filter { unit.drugIds.contains($0.id) }
            let pool = unitDrugs.count >= 4 ? unitDrugs : drugs
            let slice = Array(pool.shuffled().prefix(4))
            let pairs = slice.map {
                MatchPair(id: $0.id, left: "\($0.brandNames.first ?? $0.genericName)®", right: $0.tallManName ?? $0.genericName)
            }
            exercises.append(
                .matchPairs(
                    id: "match-brands-\(unit.id)-\(step)",
                    prompt: "Match Brand Name ↔ Generic Name",
                    pairs: pairs,
                    pearl: "ISMP Tall Man Lettering prevents fatal look-alike/sound-alike dispensing errors."
                )
            )
        }

        // 2. Stem Spotter (Decode an example generic name by its root)
        if let stem = drugStems.randomElement(),
           let exampleDrug = stem.exampleDrugs.randomElement() {
            let distractors = drugStems
                .filter { $0.id != stem.id }
                .shuffled()
                .prefix(3)
                .map(\.drugClass)
            let choices = ([stem.drugClass] + distractors).shuffled()
            exercises.append(
                .stemSpotter(
                    id: "spot-\(stem.id)-\(step)",
                    exampleDrug: exampleDrug,
                    stemItem: stem,
                    classChoices: choices
                )
            )
        }

        // 3. Duolingo Sig Word-Bank Sentence Builder
        let sigPool = sigDrills.shuffled()
        if let firstSig = sigPool.first {
            exercises.append(.sigWordBank(drill: firstSig))
        }
        if unit.focusType == "sig_codes", sigPool.count > 1 {
            exercises.append(.sigWordBank(drill: sigPool[1]))
        }

        // 4. Boss Exercises: 2 FDA-Verified Clinical Vignettes or Pharmacy Math Questions
        let focusQuestions: [QuestionItem] = {
            if unit.focusType == "math" {
                return allQuestions.filter { $0.questionType == "math_mcq" }
            }
            let byDrug = allQuestions.filter { q in
                guard let did = q.drugId else { return false }
                return unit.drugIds.contains(did)
            }
            return byDrug.isEmpty ? allQuestions : byDrug
        }()

        let adaptiveBoss = adaptiveEngine.buildAdaptiveSession(
            pool: focusQuestions,
            domains: currentExam?.domains ?? [],
            attempts: attempts,
            count: 2
        )
        for q in adaptiveBoss {
            exercises.append(.bossQuestion(question: q))
        }

        return exercises
    }

    public func completeNode(unit: SkillUnit, step: Int, earnedXP: Int) {
        completedNodeIds.insert(nodeId(unit: unit, step: step))
        awardXP(earnedXP)
    }

    public func awardXP(_ points: Int) {
        refreshDailyRollover()
        let wasBelowThreshold = todayXP < 15
        totalXP += points
        todayXP += points

        let todayKey = Self.dayKey(for: Date())
        if wasBelowThreshold && todayXP >= 15 && lastStudyDayKey != todayKey {
            streakDays += 1
            lastStudyDayKey = todayKey
        } else if lastStudyDayKey.isEmpty {
            lastStudyDayKey = todayKey
        }
        saveProgress()
    }

    public func cardState(for cardId: String) -> FSRSCardState {
        fsrsStates[cardId] ?? FSRSCardState.initial(cardId: cardId)
    }

    public func recordFlashcardReview(cardId: String, rating: FSRSRating) {
        let current = cardState(for: cardId)
        fsrsStates[cardId] = scheduler.schedule(
            state: current,
            rating: rating,
            now: Date(),
            examDate: examDate
        )
        awardXP(5)
    }

    public func recordQuestionAttempt(question: QuestionItem, selectedChoiceId: String) {
        let attempt = QuestionAttempt(
            questionId: question.id,
            domainCode: question.domainCode,
            difficulty: question.difficulty,
            selectedChoiceId: selectedChoiceId,
            isCorrect: selectedChoiceId == question.correctChoiceId,
            timestamp: Date()
        )
        attempts.append(attempt)
        saveProgress()
    }

    public func nextAdaptiveQuiz(count: Int = 10, mathOnly: Bool = false) -> [QuestionItem] {
        let filtered = mathOnly ? allQuestions.filter { $0.questionType == "math_mcq" } : allQuestions
        return adaptiveEngine.buildAdaptiveSession(
            pool: filtered,
            domains: currentExam?.domains ?? [],
            attempts: attempts,
            count: count
        )
    }

    private func loadStaticCatalog() {
        exams = packDB.loadExams()
        drugStems = packDB.loadDrugStems()
        sigDrills = packDB.loadSigDrills()
        drugs = packDB.loadDrugs()
        reloadExamContent()
    }

    private func reloadExamContent() {
        skillUnits = packDB.loadSkillUnits(examCode: selectedExamCode)
        allFlashcards = packDB.loadFlashcards(examCode: selectedExamCode)
        allQuestions = packDB.loadQuestions(examCode: selectedExamCode)
    }

    private func refreshDailyRollover() {
        let todayKey = Self.dayKey(for: Date())
        guard !lastStudyDayKey.isEmpty, lastStudyDayKey != todayKey else { return }

        let yesterdayKey = Self.dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        if lastStudyDayKey != yesterdayKey {
            if streakFreezes > 0 {
                streakFreezes -= 1
            } else {
                streakDays = 1
            }
        }
        todayXP = 0
    }

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private struct PersistedSnapshot: Codable {
        var examDate: Date
        var fsrsStates: [String: FSRSCardState]
        var attempts: [QuestionAttempt]
        var completedNodeIds: Set<String>
        var totalXP: Int
        var todayXP: Int
        var streakDays: Int
        var streakFreezes: Int
        var lastStudyDayKey: String
    }

    private func saveProgress() {
        let snap = PersistedSnapshot(
            examDate: examDate,
            fsrsStates: fsrsStates,
            attempts: attempts,
            completedNodeIds: completedNodeIds,
            totalXP: totalXP,
            todayXP: todayXP,
            streakDays: streakDays,
            streakFreezes: streakFreezes,
            lastStudyDayKey: lastStudyDayKey
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: progressFileURL, options: .atomic)
        }
    }

    private func loadSavedProgress() {
        guard let data = try? Data(contentsOf: progressFileURL),
              let snap = try? JSONDecoder().decode(PersistedSnapshot.self, from: data) else {
            return
        }
        self.examDate = snap.examDate
        self.fsrsStates = snap.fsrsStates
        self.attempts = snap.attempts
        self.completedNodeIds = snap.completedNodeIds
        self.totalXP = snap.totalXP
        self.todayXP = snap.todayXP
        self.streakDays = snap.streakDays
        self.streakFreezes = snap.streakFreezes
        self.lastStudyDayKey = snap.lastStudyDayKey
    }
}
