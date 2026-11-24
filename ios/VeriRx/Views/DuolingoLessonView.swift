import SwiftUI

struct DuolingoLessonView: View {
    var studyStore: StudyStore
    let unit: SkillUnit
    let step: Int

    @Environment(\.dismiss) private var dismiss

    struct QueueEntry: Identifiable {
        let id = UUID()
        let exercise: LessonExercise
        let isMistakeReview: Bool
    }

    struct LessonFeedback {
        let isCorrect: Bool
        let title: String
        let detail: String
        let citationUrl: String?
    }

    @State private var queue: [QueueEntry] = []
    @State private var currentIndex: Int = 0
    @State private var initialCount: Int = 1
    @State private var clearedCount: Int = 0
    @State private var comboCount: Int = 0
    @State private var earnedXP: Int = 0
    @State private var totalChecks: Int = 0
    @State private var correctChecks: Int = 0
    @State private var lessonStartDate: Date = Date()
    @State private var elapsedSeconds: Int = 0

    @State private var feedbackBanner: LessonFeedback? = nil
    @State private var isFinished: Bool = false
    @State private var showQuitConfirm: Bool = false
    @State private var successHapticTrigger: Int = 0
    @State private var errorHapticTrigger: Int = 0

    private let praiseTitles = [
        "Amazing!",
        "Spot on!",
        "Nicely done!",
        "Great job!",
        "Clinical precision!"
    ]

    private var accuracyPercent: Int {
        guard totalChecks > 0 else { return 100 }
        return Int((Double(correctChecks) / Double(totalChecks) * 100.0).rounded())
    }

    private var formattedDuration: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isFinished {
                headerBar
            }

            if isFinished {
                celebrationScreen
            } else if currentIndex < queue.count {
                let entry = queue[currentIndex]

                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if entry.isMistakeReview {
                            mistakeReviewPill
                                .padding(.top, 4)
                        }

                        exerciseContent(entry.exercise)
                            .id(entry.id)
                    }

                    if let fb = feedbackBanner {
                        bottomFeedbackDrawer(fb)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(20)
                    }
                }
            } else {
                ProgressView("Building Lesson…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if queue.isEmpty {
                let built = studyStore.buildDuolingoLesson(for: unit, step: step)
                queue = built.map { QueueEntry(exercise: $0, isMistakeReview: false) }
                initialCount = max(1, built.count)
                lessonStartDate = Date()
            }
        }
        .confirmationDialog(
            "Wait, don't go!",
            isPresented: $showQuitConfirm,
            titleVisibility: .visible
        ) {
            Button("Keep Learning", role: .cancel) {}
            Button("End Session", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You'll lose your progress from this lesson if you quit now.")
        }
        .sensoryFeedback(.success, trigger: successHapticTrigger)
        .sensoryFeedback(.error, trigger: errorHapticTrigger)
    }

    // MARK: - Top Lesson Progress Bar
    private var headerBar: some View {
        HStack(spacing: 14) {
            Button {
                if currentIndex > 0 && !isFinished {
                    showQuitConfirm = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DuoColor.hareGray)
                    .frame(width: 32, height: 32)
            }

            DuoProgressBar(
                progress: Double(clearedCount) / Double(max(1, initialCount)),
                tint: DuoColor.featherGreen,
                height: 16
            )

            if comboCount >= 2 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                    Text("\(comboCount)x")
                }
                .font(.caption.weight(.black))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DuoColor.foxOrange.opacity(0.16), in: Capsule())
                .foregroundStyle(DuoColor.foxOrange)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var mistakeReviewPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
            Text("PREVIOUS MISTAKE")
        }
        .font(.caption2.weight(.black))
        .tracking(0.6)
        .foregroundStyle(DuoColor.foxOrange)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(DuoColor.foxOrange.opacity(0.14), in: Capsule())
    }

    // MARK: - Exercise Switcher
    @ViewBuilder
    private func exerciseContent(_ exercise: LessonExercise) -> some View {
        switch exercise {
        case .matchPairs(_, let prompt, let pairs, let pearl):
            MatchPairsStepView(prompt: prompt, pairs: pairs) {
                handleOutcome(
                    exercise: exercise,
                    isCorrect: true,
                    xp: 10,
                    correctTitle: "Perfect Match! +10 XP",
                    wrongTitle: "",
                    detail: pearl,
                    citationUrl: nil
                )
            }

        case .sigWordBank(let drill):
            SigWordBankStepView(drill: drill, isLocked: feedbackBanner != nil) { passed in
                handleOutcome(
                    exercise: exercise,
                    isCorrect: passed,
                    xp: 10,
                    correctTitle: "\(randomPraise()) +10 XP",
                    wrongTitle: "Correct Sig: \(drill.correctTokens.joined(separator: " "))",
                    detail: drill.clinicalTip,
                    citationUrl: nil
                )
            }

        case .stemSpotter(_, let exampleDrug, let stemItem, let choices):
            StemSpotterStepView(
                exampleDrug: exampleDrug,
                stemItem: stemItem,
                choices: choices,
                isLocked: feedbackBanner != nil
            ) { picked in
                let ok = picked == stemItem.drugClass
                handleOutcome(
                    exercise: exercise,
                    isCorrect: ok,
                    xp: 10,
                    correctTitle: "Decoded \(stemItem.stem)! +10 XP",
                    wrongTitle: "Correct Answer: \(stemItem.drugClass)",
                    detail: "\(stemItem.clinicalPearl)\n⚠️ \(stemItem.trapNote)",
                    citationUrl: nil
                )
            }

        case .bossQuestion(let question):
            BossMcqStepView(
                question: question,
                isLocked: feedbackBanner != nil
            ) { selectedId in
                let ok = selectedId == question.correctChoiceId
                studyStore.recordQuestionAttempt(question: question, selectedChoiceId: selectedId)
                handleOutcome(
                    exercise: exercise,
                    isCorrect: ok,
                    xp: 15,
                    correctTitle: "Boss Cleared! +15 XP",
                    wrongTitle: "Correct Answer: \(question.correctChoiceId)",
                    detail: "\(question.explanation)\n\nSource: \(question.citationQuote)",
                    citationUrl: question.citationUrl
                )
            }
        }
    }

    private func handleOutcome(
        exercise: LessonExercise,
        isCorrect: Bool,
        xp: Int,
        correctTitle: String,
        wrongTitle: String,
        detail: String,
        citationUrl: String?
    ) {
        totalChecks += 1
        if isCorrect {
            correctChecks += 1
            clearedCount += 1
            comboCount += 1
            earnedXP += xp
            successHapticTrigger += 1
            DuoSound.playCorrect()
        } else {
            comboCount = 0
            errorHapticTrigger += 1
            DuoSound.playWrong()
            // Duolingo signature mistake re-queue: re-append missed exercise to the end!
            queue.append(QueueEntry(exercise: exercise, isMistakeReview: true))
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            feedbackBanner = LessonFeedback(
                isCorrect: isCorrect,
                title: isCorrect ? correctTitle : wrongTitle,
                detail: detail,
                citationUrl: citationUrl
            )
        }
    }

    private func randomPraise() -> String {
        praiseTitles[correctChecks % praiseTitles.count]
    }

    // MARK: - Full-Width Duolingo Feedback Drawer
    private func bottomFeedbackDrawer(_ fb: LessonFeedback) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: fb.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2.weight(.bold))
                Text(fb.title)
                    .font(.headline.weight(.black))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .foregroundStyle(fb.isCorrect ? DuoColor.featherGreenShadow : DuoColor.cardinalRedShadow)

            Text(fb.detail)
                .font(.footnote.weight(.medium))
                .foregroundStyle(fb.isCorrect ? DuoColor.featherGreenShadow.opacity(0.92) : DuoColor.cardinalRedShadow.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            if !fb.isCorrect {
                Text("We'll bring this one back at the end of the lesson so you nail it.")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DuoColor.cardinalRedShadow.opacity(0.8))
            }

            if let urlStr = fb.citationUrl, let url = URL(string: urlStr) {
                Link("Verify Official FDA SPL Source ↗", destination: url)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DuoColor.macawBlueShadow)
            }

            Button {
                DuoSound.playTap()
                withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                    feedbackBanner = nil
                    if currentIndex + 1 < queue.count {
                        currentIndex += 1
                    } else {
                        elapsedSeconds = max(1, Int(Date().timeIntervalSince(lessonStartDate)))
                        let finalXP = max(15, earnedXP)
                        studyStore.completeNode(unit: unit, step: step, earnedXP: finalXP)
                        DuoSound.playCelebration()
                        isFinished = true
                    }
                }
            } label: {
                Text(fb.isCorrect ? "CONTINUE" : "GOT IT")
                    .font(.headline.weight(.black))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(
                Duo3DButtonStyle(
                    fill: fb.isCorrect ? DuoColor.featherGreen : DuoColor.cardinalRed,
                    shadow: fb.isCorrect ? DuoColor.featherGreenShadow : DuoColor.cardinalRedShadow
                )
            )
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            (fb.isCorrect ? DuoColor.featherGreenLight : DuoColor.cardinalRedLight)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(fb.isCorrect ? DuoColor.featherGreen.opacity(0.35) : DuoColor.cardinalRed.opacity(0.35))
                .frame(height: 2)
        }
    }

    // MARK: - Celebration Screen
    private var celebrationScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            RxMascotView(
                mood: .celebrating,
                accentColor: DuoColor.featherGreen,
                size: 120
            )

            VStack(spacing: 6) {
                Text("Lesson Complete!")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(DuoColor.beeYellowShadow)

                Text(accuracyPercent == 100 ? "Flawless run! Zero clinical errors." : "Great persistence — every mistake reviewed!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                celebrationStatCard(
                    title: "TOTAL XP",
                    value: "+\(max(15, earnedXP))",
                    icon: "bolt.fill",
                    color: DuoColor.beeYellow,
                    shadow: DuoColor.beeYellowShadow
                )
                celebrationStatCard(
                    title: "ACCURACY",
                    value: "\(accuracyPercent)%",
                    icon: "target",
                    color: DuoColor.featherGreen,
                    shadow: DuoColor.featherGreenShadow
                )
                celebrationStatCard(
                    title: "TIME",
                    value: formattedDuration,
                    icon: "clock.fill",
                    color: DuoColor.macawBlue,
                    shadow: DuoColor.macawBlueShadow
                )
            }
            .padding(.horizontal, 16)

            HStack(spacing: 18) {
                Label("\(studyStore.streakDays) Day Streak", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DuoColor.foxOrange)

                Text("•")
                    .foregroundStyle(.secondary)

                Label("Readiness \(studyStore.readinessScore)/1600", systemImage: "checkmark.shield.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DuoColor.tealPrimary)
            }

            Spacer()

            Button {
                DuoSound.playTap()
                dismiss()
            } label: {
                Text("CONTINUE")
                    .font(.headline.weight(.black))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(
                Duo3DButtonStyle(
                    fill: DuoColor.macawBlue,
                    shadow: DuoColor.macawBlueShadow
                )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func celebrationStatCard(
        title: String,
        value: String,
        icon: String,
        color: Color,
        shadow: Color
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(color)

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                Text(value)
                    .font(.headline.weight(.black))
                    .monospacedDigit()
            }
            .foregroundStyle(shadow)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(UIColor.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color, lineWidth: 2.5)
        )
    }
}

// MARK: - 1. Tap-to-Match Pairs Mechanic (with Red Flash + Shake!)
private struct MatchPairsStepView: View {
    let prompt: String
    let pairs: [MatchPair]
    let onAllMatched: () -> Void

    @State private var leftItems: [MatchPair] = []
    @State private var rightItems: [MatchPair] = []
    @State private var selectedLeftId: String?
    @State private var selectedRightId: String?
    @State private var matchedIds: Set<String> = []
    @State private var wrongLeftId: String?
    @State private var wrongRightId: String?
    @State private var shakeTrigger: CGFloat = 0
    @State private var pairErrorHaptic: Int = 0
    @State private var pairTapHaptic: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tap the matching pairs")
                    .font(.title2.weight(.black))

                Text(prompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(leftItems) { item in
                            pairTile(
                                text: item.left,
                                isSelected: selectedLeftId == item.id,
                                isMatched: matchedIds.contains(item.id),
                                isWrong: wrongLeftId == item.id
                            ) {
                                guard !matchedIds.contains(item.id), wrongLeftId == nil else { return }
                                pairTapHaptic += 1
                                DuoSound.playTap()
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
                                isMatched: matchedIds.contains(item.id),
                                isWrong: wrongRightId == item.id
                            ) {
                                guard !matchedIds.contains(item.id), wrongRightId == nil else { return }
                                pairTapHaptic += 1
                                DuoSound.playTap()
                                selectedRightId = item.id
                                evaluateMatch()
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 140)
        }
        .onAppear {
            leftItems = pairs.shuffled()
            rightItems = pairs.shuffled()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pairTapHaptic)
        .sensoryFeedback(.error, trigger: pairErrorHaptic)
    }

    private func pairTile(
        text: String,
        isSelected: Bool,
        isMatched: Bool,
        isWrong: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(isWrong ? DuoColor.cardinalRedShadow : (isSelected ? DuoColor.macawBlueShadow : .primary))
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.horizontal, 10)
        }
        .buttonStyle(
            DuoTileButtonStyle(
                isSelected: isSelected,
                isCorrect: isMatched,
                isWrong: isWrong,
                isMuted: isMatched
            )
        )
        .modifier(DuoShakeEffect(animatableData: isWrong ? shakeTrigger : 0))
        .disabled(isMatched)
    }

    private func evaluateMatch() {
        guard let l = selectedLeftId, let r = selectedRightId else { return }
        if l == r {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                matchedIds.insert(l)
                selectedLeftId = nil
                selectedRightId = nil
            }
            if matchedIds.count == pairs.count {
                onAllMatched()
            }
        } else {
            wrongLeftId = l
            wrongRightId = r
            pairErrorHaptic += 1
            DuoSound.playWrong()
            withAnimation(.linear(duration: 0.36)) {
                shakeTrigger += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                withAnimation(.easeOut(duration: 0.15)) {
                    selectedLeftId = nil
                    selectedRightId = nil
                    wrongLeftId = nil
                    wrongRightId = nil
                }
            }
        }
    }
}

// MARK: - 2. Duolingo Sig Word-Bank Builder (True FlowLayout + Recessed Bank Slots)
private struct SigWordBankStepView: View {
    let drill: SigDrillItem
    let isLocked: Bool
    let onCheck: (Bool) -> Void

    struct BankToken: Identifiable, Hashable {
        let id: Int
        let text: String
    }

    @State private var allBankTokens: [BankToken] = []
    @State private var selectedIds: [Int] = []
    @State private var tapHaptic: Int = 0
    @Namespace private var tokenNS

    private var selectedTokens: [BankToken] {
        selectedIds.compactMap { id in allBankTokens.first(where: { $0.id == id }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Translate this prescription Sig")
                        .font(.title2.weight(.black))

                    // Mascot + Speech Bubble Prompt
                    HStack(alignment: .center, spacing: 12) {
                        RxMascotView(mood: .idle, accentColor: DuoColor.indigoPrimary, size: 62)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("RX SHORTHAND")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(DuoColor.indigoPrimary)
                            Text(drill.rxShorthand)
                                .font(.title3.weight(.black).monospaced())
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(UIColor.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(DuoColor.swanGray, lineWidth: 2)
                                )
                        )
                    }

                    // Assembled Answer Tray with Duolingo ruled lines
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 46) {
                                Rectangle().fill(DuoColor.swanGray).frame(height: 2)
                                Rectangle().fill(DuoColor.swanGray).frame(height: 2)
                                Rectangle().fill(DuoColor.swanGray).frame(height: 2)
                            }
                            .padding(.top, 42)

                            DuoFlowLayout(spacing: 8, lineSpacing: 10) {
                                ForEach(selectedTokens) { token in
                                    Button {
                                        guard !isLocked else { return }
                                        tapHaptic += 1
                                        DuoSound.playTap()
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedIds.removeAll { $0 == token.id }
                                        }
                                    } label: {
                                        Text(token.text)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                    }
                                    .buttonStyle(DuoTileButtonStyle(isSelected: false, cornerRadius: 12, depth: 3))
                                    .matchedGeometryEffect(id: token.id, in: tokenNS)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
                        }
                    }

                    // Word Bank (selected tokens leave a recessed gray placeholder slot!)
                    DuoFlowLayout(spacing: 8, lineSpacing: 10) {
                        ForEach(allBankTokens) { token in
                            let isUsed = selectedIds.contains(token.id)

                            ZStack {
                                // Recessed placeholder slot
                                Text(token.text)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.clear)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(DuoColor.swanGray.opacity(0.75))
                                    )
                                    .padding(.bottom, 3)

                                if !isUsed {
                                    Button {
                                        guard !isLocked else { return }
                                        tapHaptic += 1
                                        DuoSound.playTap()
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedIds.append(token.id)
                                        }
                                    } label: {
                                        Text(token.text)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                    }
                                    .buttonStyle(DuoTileButtonStyle(isSelected: false, cornerRadius: 12, depth: 3))
                                    .matchedGeometryEffect(id: token.id, in: tokenNS)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .padding(.bottom, 120)
            }

            if !isLocked {
                stickyCheckBar(isEnabled: !selectedTokens.isEmpty) {
                    let assembled = selectedTokens.map(\.text)
                    onCheck(assembled == drill.correctTokens)
                }
            }
        }
        .onAppear {
            if allBankTokens.isEmpty {
                let combined = (drill.correctTokens + drill.distractorTokens).shuffled()
                allBankTokens = combined.enumerated().map { BankToken(id: $0.offset, text: $0.element) }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapHaptic)
    }
}

// MARK: - 3. Drug Stem Spotter (Select -> CHECK flow + Highlighted Stem!)
private struct StemSpotterStepView: View {
    let exampleDrug: String
    let stemItem: DrugStemItem
    let choices: [String]
    let isLocked: Bool
    let onCheck: (String) -> Void

    @State private var selectedOption: String?
    @State private var tapHaptic: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Decode the drug stem")
                        .font(.title2.weight(.black))

                    // Mascot + Highlighted Drug Card
                    HStack(spacing: 14) {
                        RxMascotView(mood: .idle, accentColor: DuoColor.tealPrimary, size: 60)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("WHICH DRUG CLASS?")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(DuoColor.tealPrimary)

                            highlightedDrugName
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(UIColor.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(DuoColor.swanGray, lineWidth: 2)
                                )
                        )
                    }

                    VStack(spacing: 12) {
                        ForEach(choices, id: \.self) { option in
                            let isSelected = selectedOption == option
                            let isCorrect = isLocked && option == stemItem.drugClass
                            let isWrong = isLocked && isSelected && option != stemItem.drugClass

                            Button {
                                guard !isLocked else { return }
                                tapHaptic += 1
                                DuoSound.playTap()
                                selectedOption = option
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(isCorrect ? DuoColor.featherGreenShadow : (isWrong ? DuoColor.cardinalRedShadow : (isSelected ? DuoColor.macawBlueShadow : .primary)))
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if isCorrect {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(DuoColor.featherGreen)
                                    } else if isWrong {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(DuoColor.cardinalRed)
                                    }
                                }
                                .padding(16)
                            }
                            .buttonStyle(
                                DuoTileButtonStyle(
                                    isSelected: isSelected && !isLocked,
                                    isCorrect: isCorrect,
                                    isWrong: isWrong
                                )
                            )
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 140)
            }

            if !isLocked {
                stickyCheckBar(isEnabled: selectedOption != nil) {
                    if let picked = selectedOption {
                        onCheck(picked)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapHaptic)
    }

    private var highlightedDrugName: some View {
        let cleanStem = stemItem.stem
            .components(separatedBy: "/")
            .first?
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased() ?? ""

        if !cleanStem.isEmpty,
           let range = exampleDrug.lowercased().range(of: cleanStem) {
            let prefix = String(exampleDrug[..<range.lowerBound])
            let match = String(exampleDrug[range])
            let suffix = String(exampleDrug[range.upperBound...])
            return AnyView(
                HStack(spacing: 0) {
                    Text(prefix)
                        .font(.title2.weight(.heavy))
                    Text(match)
                        .font(.title2.weight(.black))
                        .foregroundStyle(DuoColor.tealPrimary)
                        .underline(true, color: DuoColor.tealPrimary)
                    Text(suffix)
                        .font(.title2.weight(.heavy))
                }
            )
        } else {
            return AnyView(
                Text("\(exampleDrug) (\(stemItem.stem))")
                    .font(.title3.weight(.black))
            )
        }
    }
}

// MARK: - 4. Boss FDA Vignette / Math MCQ (Select -> CHECK flow)
private struct BossMcqStepView: View {
    let question: QuestionItem
    let isLocked: Bool
    let onCheck: (String) -> Void

    @State private var selectedId: String?
    @State private var tapHaptic: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("BOSS CHALLENGE", systemImage: "crown.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(DuoColor.foxOrange)
                        Spacer()
                        Text("DIFF \(question.difficulty)/5")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(DuoColor.foxOrange.opacity(0.15), in: Capsule())
                            .foregroundStyle(DuoColor.foxOrange)
                    }

                    Text(question.stem)
                        .font(.body.weight(.bold))
                        .lineSpacing(3)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )

                    VStack(spacing: 12) {
                        ForEach(question.choices) { choice in
                            let isSelected = selectedId == choice.id
                            let isCorrect = isLocked && choice.id == question.correctChoiceId
                            let isWrong = isLocked && isSelected && choice.id != question.correctChoiceId

                            Button {
                                guard !isLocked else { return }
                                tapHaptic += 1
                                DuoSound.playTap()
                                selectedId = choice.id
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(choice.id)
                                            .font(.caption.weight(.black))
                                            .frame(width: 24, height: 24)
                                            .background(
                                                (isCorrect ? DuoColor.featherGreen : (isWrong ? DuoColor.cardinalRed : (isSelected ? DuoColor.macawBlue : DuoColor.swanGray)))
                                                    .opacity(isSelected || isCorrect || isWrong ? 1.0 : 0.7),
                                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            )
                                            .foregroundStyle(isSelected || isCorrect || isWrong ? .white : .secondary)

                                        Text(choice.text)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }

                                    if isLocked {
                                        Text(choice.rationale)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(isCorrect ? DuoColor.featherGreenShadow : .secondary)
                                            .padding(.leading, 34)
                                    }
                                }
                                .padding(14)
                            }
                            .buttonStyle(
                                DuoTileButtonStyle(
                                    isSelected: isSelected && !isLocked,
                                    isCorrect: isCorrect,
                                    isWrong: isWrong
                                )
                            )
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 160)
            }

            if !isLocked {
                stickyCheckBar(isEnabled: selectedId != nil) {
                    if let picked = selectedId {
                        onCheck(picked)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapHaptic)
    }
}

// MARK: - Shared Sticky Bottom CHECK Bar
private func stickyCheckBar(isEnabled: Bool, action: @escaping () -> Void) -> some View {
    VStack(spacing: 0) {
        Rectangle()
            .fill(DuoColor.swanGray)
            .frame(height: 2)

        Button(action: action) {
            Text("CHECK")
                .font(.headline.weight(.black))
                .tracking(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(
            Duo3DButtonStyle(
                fill: DuoColor.featherGreen,
                shadow: DuoColor.featherGreenShadow,
                isDisabled: !isEnabled
            )
        )
        .disabled(!isEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(UIColor.systemBackground))
    }
}
