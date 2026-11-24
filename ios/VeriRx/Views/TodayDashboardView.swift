import SwiftUI

struct PracticeHubView: View {
    var studyStore: StudyStore
    var onOpenPaywall: () -> Void

    var body: some View {
        List {
            Section("Daily Spaced Repetition (FSRS v5)") {
                NavigationLink {
                    FlashcardSessionView(
                        studyStore: studyStore,
                        cards: studyStore.dueFlashcards.isEmpty ? studyStore.allFlashcards : studyStore.dueFlashcards
                    )
                } label: {
                    HStack {
                        Label("FSRS Memory Workout", systemImage: "dumbbell.fill")
                            .foregroundStyle(.teal)
                        Spacer()
                        Text("\(studyStore.dueFlashcards.count) due")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Adaptive Exam Simulation") {
                NavigationLink {
                    QuizSessionView(
                        title: "Adaptive Practice (10 Qs)",
                        studyStore: studyStore,
                        questions: studyStore.nextAdaptiveQuiz(count: 10, mathOnly: false)
                    )
                } label: {
                    Label("Start Adaptive CAT Session", systemImage: "bolt.circle.fill")
                }

                NavigationLink {
                    QuizSessionView(
                        title: "Pharmacy Calculations",
                        studyStore: studyStore,
                        questions: studyStore.nextAdaptiveQuiz(count: 10, mathOnly: true)
                    )
                } label: {
                    Label("Pharmacy Math & Alligation Drill", systemImage: "plus.forwardslash.minus")
                }
            }

            Section("By Official Blueprint Domain") {
                ForEach(studyStore.currentExam?.domains ?? []) { domain in
                    let domainPool = studyStore.allQuestions.filter { $0.domainCode == domain.code }
                    NavigationLink {
                        QuizSessionView(
                            title: domain.name,
                            studyStore: studyStore,
                            questions: domainPool
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(domain.name)
                                    .font(.body.weight(.medium))
                                Text("Exam Weight: \(String(format: "%.1f", domain.weight_pct))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(domainPool.count) Qs")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Drills & Review")
    }
}
