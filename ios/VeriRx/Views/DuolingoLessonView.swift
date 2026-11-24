import SwiftUI

struct DuolingoLessonView: View {
    var studyStore: StudyStore
    let unit: SkillUnit
    let step: Int

    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [LessonExercise] = []
    @State private var currentIndex: Int = 0
    @State private var comboCount: Int = 0
    @State private var earnedXP: Int = 0
    @State private var feedbackBanner: LessonFeedback? = nil
    @State private var isFinished: Bool = false

    struct LessonFeedback {
        let isCorrect: Bool
        let title: String
        let detail: String
        let citationUrl: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if isFinished {
                celebrationScreen
            } else if currentIndex < exercises.count {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        exerciseContent(exercises[currentIndex])
                            .id(exercises[currentIndex].id)
                            .padding(20)
                            .padding(.bottom, 150)
                    }

                    if let fb = feedbackBanner {
                        bottomFeedbackDrawer(fb)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                ProgressView("Building Lesson…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if exercises.isEmpty {
                exercises = studyStore.buildDuolingoLesson(for: unit, step: step)
            }
        }
        .sensoryFeedback(.success, trigger: earnedXP)
    }

    private var headerBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(isFinished ? exercises.count : currentIndex),
                total: Double(max(1, exercises.count))
            )
            .tint(.green)
            .scaleEffect(x: 1, y: 1.8, anchor: .center)

            if comboCount >= 2 {
                Text("\(comboCount)x 🔥")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func exerciseContent(_ exercise: LessonExercise) -> some View {
        switch exercise {
        case .matchPairs(_, let prompt, let pairs, let pearl):
            MatchPairsStepView(prompt: prompt, pairs: pairs) {
                comboCount += 1
                earnedXP += 10
                withAnimation(.spring(duration: 0.25)) {
                    feedbackBanner = LessonFeedback(
                        isCorrect: true,
                        title: "Perfect Match! +10 XP",
                        detail: pearl,
                        citationUrl: nil
                    )
                }
            }

        case .sigWordBank(let drill):
            SigWordBankStepView(drill: drill, isLocked: feedbackBanner != nil) { passed in
                if passed {
                    comboCount += 1
                    earnedXP += 10
                } else {
                    comboCount = 0
                }
                withAnimation(.spring(duration: 0.25)) {
                    feedbackBanner = LessonFeedback(
                        isCorrect: passed,
                        title: passed ? "Exact Translation! +10 XP" : "Correct Sig: \(drill.correctTokens.joined(separator: " "))",
                        detail: drill.clinicalTip,
                        citationUrl: nil
                    )
                }
            }

        case .stemSpotter(_, let exampleDrug, let stemItem, let choices):
            StemSpotterStepView(
                exampleDrug: exampleDrug,
                stemItem: stemItem,
                choices: choices,
                isLocked: feedbackBanner != nil
            ) { picked in
                let ok = picked == stemItem.drugClass
                if ok {
                    comboCount += 1
                    earnedXP += 10
                } else {
                    comboCount = 0
                }
                withAnimation(.spring(duration: 0.25)) {
                    feedbackBanner = LessonFeedback(
                        isCorrect: ok,
                        title: ok ? "Decoded \(stemItem.stem)! +10 XP" : "Answer: \(stemItem.drugClass)",
                        detail: "\(stemItem.clinicalPearl)\n⚠️ \(stemItem.trapNote)",
                        citationUrl: nil
                    )
                }
            }

        case .bossQuestion(let question):
            BossMcqStepView(
                question: question,
                isLocked: feedbackBanner != nil
            ) { selectedId in
                let ok = selectedId == question.correctChoiceId
                studyStore.recordQuestionAttempt(question: question, selectedChoiceId: selectedId)
                if ok {
                    comboCount += 1
                    earnedXP += 15
                } else {
                    comboCount = 0
                }
                withAnimation(.spring(duration: 0.25)) {
                    feedbackBanner = LessonFeedback(
                        isCorrect: ok,
                        title: ok ? "Boss Cleared! +15 XP" : "Correct Answer: \(question.correctChoiceId)",
                        detail: "\(question.explanation)\n\nSource: \(question.citationQuote)",
                        citationUrl: question.citationUrl
                    )
                }
            }
        }
    }

    private func bottomFeedbackDrawer(_ fb: LessonFeedback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: fb.isCorrect ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                Text(fb.title)
                    .font(.headline.bold())
                Spacer()
            }
            .foregroundStyle(fb.isCorrect ? .green : .red)

            Text(fb.detail)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let urlStr = fb.citationUrl, let url = URL(string: urlStr) {
                Link("Verify Official FDA SPL Source ↗", destination: url)
                    .font(.caption2.bold())
            }

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    feedbackBanner = nil
                    if currentIndex + 1 < exercises.count {
                        currentIndex += 1
                    } else {
                        studyStore.completeNode(unit: unit, step: step, earnedXP: max(15, earnedXP))
                        isFinished = true
                    }
                }
            } label: {
                Text("CONTINUE")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(fb.isCorrect ? Color.green : Color.red, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var celebrationScreen: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "flame.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(.orange)

            Text("Lesson Complete!")
                .font(.largeTitle.bold())

            HStack(spacing: 16) {
                statPill(title: "EARNED", value: "+\(max(15, earnedXP)) XP", color: .yellow)
                statPill(title: "STREAK", value: "\(studyStore.streakDays) Days 🔥", color: .orange)
            }

            Text("PTCE Readiness Score: \(studyStore.readinessScore) / 1600")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("BACK TO PATH")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(value).font(.headline.bold()).foregroundStyle(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 1. Tap-to-Match Pairs Mechanic
private struct MatchPairsStepView: View {
    let prompt: String
    let pairs: [MatchPair]
    let onAllMatched: () -> Void

    @State private var leftItems: [MatchPair] = []
    @State private var rightItems: [MatchPair] = []
    @State private var selectedLeftId: String?
    @State private var selectedRightId: String?
    @State private var matchedIds: Set<String> = []
    @State private var wrongFlash: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("TAP THE MATCHING PAIRS", systemImage: "sparkles")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.teal)
            Text(prompt)
                .font(.title3.bold())

            HStack(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(leftItems) { item in
                        pairTile(
                            text: item.left,
                            isSelected: selectedLeftId == item.id,
                            isMatched: matchedIds.contains(item.id)
                        ) {
                            guard !matchedIds.contains(item.id) else { return }
                            selectedLeftId = item.id
                            evaluateMatch()
                        }
                    }
                }
                VStack(spacing: 12) {
                    ForEach(rightItems) { item in
                        pairTile(
                            text: item.right,
                            isSelected: selectedRightId == item.id,
                            isMatched: matchedIds.contains(item.id)
                        ) {
                            guard !matchedIds.contains(item.id) else { return }
                            selectedRightId = item.id
                            evaluateMatch()
                        }
                    }
                }
            }
        }
        .onAppear {
            leftItems = pairs.shuffled()
            rightItems = pairs.shuffled()
        }
    }

    private func pairTile(text: String, isSelected: Bool, isMatched: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 62)
                .padding(.horizontal, 8)
                .background(
                    isMatched ? Color.green.opacity(0.18) :
                        (isSelected ? Color.teal.opacity(0.2) : Color(.secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isMatched ? Color.green : (isSelected ? Color.teal : Color(.separator)),
                            lineWidth: isSelected || isMatched ? 2 : 1
                        )
                )
                .opacity(isMatched ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
    }

    private func evaluateMatch() {
        guard let l = selectedLeftId, let r = selectedRightId else { return }
        if l == r {
            matchedIds.insert(l)
            selectedLeftId = nil
            selectedRightId = nil
            if matchedIds.count == pairs.count {
                onAllMatched()
            }
        } else {
            wrongFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                selectedLeftId = nil
                selectedRightId = nil
                wrongFlash = false
            }
        }
    }
}

// MARK: - 2. Duolingo Sig Word-Bank Sentence Builder
private struct SigWordBankStepView: View {
    let drill: SigDrillItem
    let isLocked: Bool
    let onCheck: (Bool) -> Void

    @State private var bankTokens: [IndexedToken] = []
    @State private var selectedTokens: [IndexedToken] = []

    struct IndexedToken: Identifiable, Hashable {
        let id: Int
        let text: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("TRANSLATE THIS PRESCRIPTION SIG", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.indigo)

            HStack {
                Text("Rx Sig:")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Text(drill.rxShorthand)
                    .font(.title2.bold().monospaced())
                    .foregroundStyle(.indigo)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            // Assembled Answer Tray
            VStack(alignment: .leading, spacing: 8) {
                Text("Patient Label Instructions:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                FlowTokenGrid(tokens: selectedTokens, tint: .indigo) { tapped in
                    guard !isLocked else { return }
                    selectedTokens.removeAll { $0.id == tapped.id }
                    bankTokens.append(tapped)
                }
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }

            // Available Word Bank
            FlowTokenGrid(tokens: bankTokens, tint: .secondary) { tapped in
                guard !isLocked else { return }
                bankTokens.removeAll { $0.id == tapped.id }
                selectedTokens.append(tapped)
            }

            if !isLocked {
                Button {
                    let assembled = selectedTokens.map(\.text)
                    onCheck(assembled == drill.correctTokens)
                } label: {
                    Text("CHECK TRANSLATION")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedTokens.isEmpty ? Color.gray.opacity(0.3) : Color.indigo, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(selectedTokens.isEmpty)
            }
        }
        .onAppear {
            let combined = (drill.correctTokens + drill.distractorTokens).shuffled()
            bankTokens = combined.enumerated().map { IndexedToken(id: $0.offset, text: $0.element) }
        }
    }
}

private struct FlowTokenGrid: View {
    let tokens: [SigWordBankStepView.IndexedToken]
    let tint: Color
    let onTap: (SigWordBankStepView.IndexedToken) -> Void

    private let columns = [GridItem(.adaptive(minimum: 105), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tokens) { token in
                Button {
                    onTap(token)
                } label: {
                    Text(token.text)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(tint.opacity(0.45), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 3. Drug Stem Spotter Mechanic
private struct StemSpotterStepView: View {
    let exampleDrug: String
    let stemItem: DrugStemItem
    let choices: [String]
    let isLocked: Bool
    let onSelect: (String) -> Void

    @State private var picked: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("DECODE THE DRUG STEM", systemImage: "wand.and.stars")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.teal)

            Text("Based on the stem \"\(stemItem.stem)\", which class does \(exampleDrug) belong to?")
                .font(.title3.bold())

            ForEach(choices, id: \.self) { option in
                Button {
                    guard !isLocked else { return }
                    picked = option
                    onSelect(option)
                } label: {
                    HStack {
                        Text(option)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if picked == option {
                            Image(systemName: option == stemItem.drugClass ? "checkmark.circle.fill" : "xmark.circle.fill")
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(picked == option ? Color.teal : Color(.separator), lineWidth: picked == option ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 4. Boss FDA Vignette / Math MCQ Mechanic
private struct BossMcqStepView: View {
    let question: QuestionItem
    let isLocked: Bool
    let onAnswer: (String) -> Void

    @State private var selectedId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("BOSS CHALLENGE · DIFF \(question.difficulty)/5", systemImage: "crown.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.orange)
                Spacer()
            }

            Text(question.stem)
                .font(.body.weight(.semibold))
                .lineSpacing(3)

            ForEach(question.choices) { choice in
                Button {
                    guard !isLocked else { return }
                    selectedId = choice.id
                    onAnswer(choice.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(choice.id).")
                                .font(.subheadline.bold())
                            Text(choice.text)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        if isLocked {
                            Text(choice.rationale)
                                .font(.caption)
                                .foregroundStyle(choice.id == question.correctChoiceId ? .green : .secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor(for: choice.id), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func borderColor(for id: String) -> Color {
        guard isLocked else { return Color(.separator).opacity(0.5) }
        if id == question.correctChoiceId { return .green }
        if id == selectedId { return .red }
        return .clear
    }
}
