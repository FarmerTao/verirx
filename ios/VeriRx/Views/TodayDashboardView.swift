import SwiftUI

struct TodayDashboardView: View {
    @Bindable var studyStore: StudyStore
    var onOpenPaywall: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                scoreHeroCard
                dueFlashcardsCard
                quickActionsGrid

                if !studyStore.isProUnlocked {
                    proBanner
                }
            }
            .padding()
        }
        .navigationTitle(studyStore.currentExam?.displayName ?? "VeriRx")
    }

    private var scoreHeroCard: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ESTIMATED PTCE READINESS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(studyStore.readinessScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(studyStore.readinessScore >= 1400 ? .green : .teal)
                    Text("/ 1600")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Passing Standard: 1400 · \(studyStore.daysUntilExam) days until exam")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: studyStore.readinessScore >= 1400 ? "checkmark.seal.fill" : "gauge.with.dots.needle.67percent")
                .font(.system(size: 38))
                .foregroundStyle(.teal)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var dueFlashcardsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("FSRS Spaced Repetition Queue", systemImage: "rectangle.stack.fill")
                    .font(.headline)
                Spacer()
                Text("\(studyStore.dueFlashcards.count) due")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
            }
            Text("FDA-cited drug cards scheduled dynamically before your exam date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            NavigationLink {
                FlashcardSessionView(
                    studyStore: studyStore,
                    cards: studyStore.dueFlashcards
                )
            } label: {
                Text(studyStore.dueFlashcards.isEmpty ? "All Caught Up Today" : "Review Due Cards Now")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(studyStore.dueFlashcards.isEmpty ? Color.gray.opacity(0.3) : Color.teal, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(studyStore.dueFlashcards.isEmpty ? Color.secondary : Color.white)
            }
            .disabled(studyStore.dueFlashcards.isEmpty)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var quickActionsGrid: some View {
        HStack(spacing: 14) {
            NavigationLink {
                QuizSessionView(
                    title: "Adaptive CAT Quiz",
                    studyStore: studyStore,
                    questions: studyStore.nextAdaptiveQuiz(count: 10, mathOnly: false)
                )
            } label: {
                actionTile(
                    title: "Adaptive CAT",
                    subtitle: "10 mixed items matched to your mastery",
                    icon: "brain.head.profile",
                    tint: .indigo
                )
            }

            NavigationLink {
                QuizSessionView(
                    title: "Pharmacy Math Drill",
                    studyStore: studyStore,
                    questions: studyStore.nextAdaptiveQuiz(count: 10, mathOnly: true)
                )
            } label: {
                actionTile(
                    title: "Math Lab",
                    subtitle: "Days supply, mg/kg, alligation & IV drip",
                    icon: "function",
                    tint: .orange
                )
            }
        }
    }

    private func actionTile(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var proBanner: some View {
        Button(action: onOpenPaywall) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Full Top 200 Deck & Unlimited CAT")
                        .font(.subheadline.bold())
                    Text("Every rationale verified against official FDA SPL labels.")
                        .font(.caption)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
            }
            .padding()
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [.teal, .indigo], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
    }
}

struct PracticeHubView: View {
    var studyStore: StudyStore
    var onOpenPaywall: () -> Void

    var body: some View {
        List {
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
                    let domainPool = studyStore.accessibleQuestions.filter { $0.domainCode == domain.code }
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
        .navigationTitle("Practice")
    }
}
