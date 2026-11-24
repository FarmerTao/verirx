import Foundation
import Observation

@Observable
public final class StudyStore {
    public private(set) var exams: [ExamTrack] = []
    public var selectedExamCode: String = "PTCE" {
        didSet { reloadExamContent() }
    }

    public private(set) var drugs: [DrugItem] = []
    public private(set) var allFlashcards: [FlashcardItem] = []
    public private(set) var allQuestions: [QuestionItem] = []

    public private(set) var fsrsStates: [String: FSRSCardState] = [:]
    public private(set) var attempts: [QuestionAttempt] = []
    public var examDate: Date {
        didSet { saveProgress() }
    }
    public var hasAcceptedDisclaimer: Bool {
        didSet { UserDefaults.standard.set(hasAcceptedDisclaimer, forKey: "verirx.accepted_disclaimer") }
    }
    public var isProUnlocked: Bool = false

    public let scheduler = FSRSScheduler(desiredRetention: 0.90)
    public let adaptiveEngine = AdaptiveQuizEngine()
    private let packDB: ContentPackDatabase
    private let progressFileURL: URL

    public init(packDB: ContentPackDatabase = ContentPackDatabase()) {
        self.packDB = packDB
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.progressFileURL = appSupport.appendingPathComponent("verirx_progress_v1.json")

        self.hasAcceptedDisclaimer = UserDefaults.standard.bool(forKey: "verirx.accepted_disclaimer")
        self.examDate = Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()

        loadStaticCatalog()
        loadSavedProgress()
    }

    public var currentExam: ExamTrack? {
        exams.first { $0.examCode == selectedExamCode } ?? exams.first
    }

    public var accessibleFlashcards: [FlashcardItem] {
        isProUnlocked ? allFlashcards : allFlashcards.filter(\.isFreeTier)
    }

    public var accessibleQuestions: [QuestionItem] {
        isProUnlocked ? allQuestions : allQuestions.filter(\.isFreeTier)
    }

    public var dueFlashcards: [FlashcardItem] {
        let now = Date()
        return accessibleFlashcards.filter { card in
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

    public func cardState(for cardId: String) -> FSRSCardState {
        fsrsStates[cardId] ?? FSRSCardState.initial(cardId: cardId)
    }

    public func recordFlashcardReview(cardId: String, rating: FSRSRating) {
        let current = cardState(for: cardId)
        let updated = scheduler.schedule(
            state: current,
            rating: rating,
            now: Date(),
            examDate: examDate
        )
        fsrsStates[cardId] = updated
        saveProgress()
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
        let basePool = accessibleQuestions
        let filtered = mathOnly ? basePool.filter { $0.questionType == "math_mcq" } : basePool
        return adaptiveEngine.buildAdaptiveSession(
            pool: filtered,
            domains: currentExam?.domains ?? [],
            attempts: attempts,
            count: count
        )
    }

    private func loadStaticCatalog() {
        exams = packDB.loadExams()
        drugs = packDB.loadDrugs()
        reloadExamContent()
    }

    private func reloadExamContent() {
        allFlashcards = packDB.loadFlashcards(examCode: selectedExamCode)
        allQuestions = packDB.loadQuestions(examCode: selectedExamCode)
    }

    private struct PersistedSnapshot: Codable {
        var examDate: Date
        var fsrsStates: [String: FSRSCardState]
        var attempts: [QuestionAttempt]
    }

    private func saveProgress() {
        let snap = PersistedSnapshot(
            examDate: examDate,
            fsrsStates: fsrsStates,
            attempts: attempts
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
    }
}
