import SwiftUI

struct SelectedLessonRoute: Identifiable, Hashable {
    let unit: SkillUnit
    let step: Int
    var id: String { "\(unit.id)-\(step)" }
}

private struct NodeMeta {
    let step: Int
    let title: String
    let subtitle: String
    let icon: String
    let xpReward: Int
}

struct SkillPathView: View {
    @Bindable var studyStore: StudyStore
    @State private var activeLesson: SelectedLessonRoute?
    @State private var previewRoute: SelectedLessonRoute?
    @State private var bounceStart = false

    private let nodeMetas: [NodeMeta] = [
        NodeMeta(
            step: 1,
            title: "Roots & Match",
            subtitle: "Decode drug stems & brand-generic pairs",
            icon: "puzzlepiece.fill",
            xpReward: 20
        ),
        NodeMeta(
            step: 2,
            title: "Sig Builder",
            subtitle: "Assemble real prescription directions",
            icon: "text.bubble.fill",
            xpReward: 25
        ),
        NodeMeta(
            step: 3,
            title: "Boss Challenge",
            subtitle: "FDA-verified clinical & math exam boss",
            icon: "crown.fill",
            xpReward: 35
        )
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topGamifiedHUD
                Rectangle()
                    .fill(DuoColor.swanGray)
                    .frame(height: 2)

                ScrollView {
                    VStack(spacing: 32) {
                        dailyQuestCard

                        ForEach(Array(studyStore.skillUnits.enumerated()), id: \.element.id) { idx, unit in
                            unitSection(unit, unitIndex: idx)
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.bottom, previewRoute != nil ? 170 : 28)
                }
                .background(Color(UIColor.systemBackground))
                .onTapGesture {
                    if previewRoute != nil {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            previewRoute = nil
                        }
                    }
                }
            }

            if let route = previewRoute {
                nodePreviewCard(for: route)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bounceStart = true
            }
        }
        .fullScreenCover(item: $activeLesson) { route in
            DuolingoLessonView(
                studyStore: studyStore,
                unit: route.unit,
                step: route.step
            )
        }
    }

    // MARK: - Sticky Top HUD
    private var topGamifiedHUD: some View {
        HStack(spacing: 16) {
            hudBadge(
                icon: "flame.fill",
                value: "\(studyStore.streakDays)",
                color: studyStore.todayXP >= 15 ? DuoColor.foxOrange : DuoColor.hareGray
            )

            hudBadge(
                icon: "snowflake",
                value: "\(studyStore.streakFreezes)",
                color: DuoColor.macawBlue
            )

            Spacer()

            hudBadge(
                icon: "bolt.fill",
                value: "\(studyStore.totalXP)",
                color: DuoColor.beeYellow
            )

            hudBadge(
                icon: "checkmark.shield.fill",
                value: "\(studyStore.readinessScore)",
                color: DuoColor.featherGreen
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color(UIColor.systemBackground))
    }

    private func hudBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    // MARK: - Daily Quest Card
    private var dailyQuestCard: some View {
        let clampedXP = min(studyStore.todayXP, studyStore.dailyGoalXP)
        let progress = Double(clampedXP) / Double(max(1, studyStore.dailyGoalXP))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("DAILY QUEST", systemImage: "star.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(DuoColor.foxOrange)
                Spacer()
                Text("\(clampedXP) / \(studyStore.dailyGoalXP) XP")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
            }

            DuoProgressBar(
                progress: progress,
                tint: progress >= 1 ? DuoColor.beeYellow : DuoColor.featherGreen,
                height: 14
            )

            if !studyStore.dueFlashcards.isEmpty {
                NavigationLink {
                    FlashcardSessionView(
                        studyStore: studyStore,
                        cards: studyStore.dueFlashcards
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                        Text("Warm-up: \(studyStore.dueFlashcards.count) FSRS cards due")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DuoColor.macawBlue)
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DuoColor.swanGray, lineWidth: 2)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Unit Banner & S-Curve Path
    private func unitSection(_ unit: SkillUnit, unitIndex: Int) -> some View {
        let palette = DuoUnitPalette.forTheme(unit.themeColor)
        let completedCount = studyStore.unitCompletedCount(for: unit)
        let flipCurve = unitIndex % 2 == 1

        return VStack(spacing: 26) {
            // Chunky 3D Unit Header Banner
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNIT \(unit.unitOrder)")
                        .font(.caption2.weight(.black))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(unit.title.replacingOccurrences(of: "Unit \(unit.unitOrder) · ", with: ""))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)

                    Text(unit.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: unit.iconName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(completedCount)/3")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.18), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.shadow)
                        .offset(y: 4)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.primary)
                }
            )
            .padding(.bottom, 4)
            .padding(.horizontal, 16)

            // Winding Path Nodes with Companion Mascot
            ZStack {
                // Mascot standing beside the middle of the S-curve
                RxMascotView(
                    mood: completedCount == 3 ? .celebrating : (completedCount > 0 ? .happy : .idle),
                    accentColor: palette.primary,
                    size: 74
                )
                .offset(x: flipCurve ? 105 : -105, y: 12)

                VStack(spacing: 24) {
                    ForEach(nodeMetas, id: \.step) { meta in
                        let baseOffset: CGFloat = {
                            switch meta.step {
                            case 1: return -46
                            case 2: return 46
                            default: return 0
                            }
                        }()
                        let xOffset = flipCurve ? -baseOffset : baseOffset
                        pathNodeButton(
                            unit: unit,
                            meta: meta,
                            xOffset: xOffset,
                            palette: palette
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pathNodeButton(
        unit: SkillUnit,
        meta: NodeMeta,
        xOffset: CGFloat,
        palette: DuoUnitPalette
    ) -> some View {
        let state = studyStore.nodeState(unit: unit, step: meta.step)
        let isSelected = previewRoute?.unit.id == unit.id && previewRoute?.step == meta.step

        let fillColor: Color = {
            switch state {
            case .completed: return DuoColor.beeYellow
            case .current: return palette.primary
            case .locked: return DuoColor.swanGray
            }
        }()

        let shadowColor: Color = {
            switch state {
            case .completed: return DuoColor.beeYellowShadow
            case .current: return palette.shadow
            case .locked: return DuoColor.swanShadow
            }
        }()

        let iconColor: Color = (state == .locked) ? DuoColor.hareGray : .white
        let iconName: String = {
            switch state {
            case .completed: return "checkmark.seal.fill"
            case .current: return meta.icon
            case .locked: return meta.step == 3 ? "crown.fill" : "lock.fill"
            }
        }()

        return VStack(spacing: 6) {
            ZStack(alignment: .top) {
                // Halo ring for active node
                if state == .current {
                    Circle()
                        .stroke(palette.primary.opacity(0.28), lineWidth: 6)
                        .frame(width: 92, height: 92)
                        .offset(y: -6)
                }

                Button {
                    DuoSound.playTap()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        previewRoute = SelectedLessonRoute(unit: unit, step: meta.step)
                    }
                } label: {
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .buttonStyle(
                    DuoNodeButtonStyle(
                        fill: fillColor,
                        shadow: shadowColor,
                        diameter: 72,
                        depth: 7
                    )
                )
                .scaleEffect(isSelected ? 1.07 : 1.0)

                // Floating "START" bubble above the current active node
                if state == .current {
                    Text("START")
                        .font(.caption.weight(.black))
                        .tracking(0.6)
                        .foregroundStyle(palette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(UIColor.systemBackground))
                                .overlay(
                                    Capsule()
                                        .stroke(DuoColor.swanGray, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        )
                        .offset(y: bounceStart ? -36 : -30)
                }
            }

            Text(meta.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(state == .locked ? DuoColor.hareGray : .primary)
        }
        .offset(x: xOffset)
        .padding(.top, state == .current ? 24 : 0)
    }

    // MARK: - Duolingo-Style Bottom Node Popover Card
    private func nodePreviewCard(for route: SelectedLessonRoute) -> some View {
        let meta = nodeMetas.first { $0.step == route.step } ?? nodeMetas[0]
        let state = studyStore.nodeState(unit: route.unit, step: route.step)
        let palette = DuoUnitPalette.forTheme(route.unit.themeColor)

        let cardFill: Color = {
            switch state {
            case .completed: return DuoColor.beeYellow
            case .current: return palette.primary
            case .locked: return Color(UIColor.secondarySystemBackground)
            }
        }()

        let cardShadow: Color = {
            switch state {
            case .completed: return DuoColor.beeYellowShadow
            case .current: return palette.shadow
            case .locked: return DuoColor.swanShadow
            }
        }()

        let textColor: Color = (state == .locked) ? .primary : .white

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meta.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(textColor)
                    Text(meta.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(state == .locked ? .secondary : .white.opacity(0.92))
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        previewRoute = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(state == .locked ? DuoColor.hareGray : .white.opacity(0.8))
                }
            }

            if state == .locked {
                Text("Complete the previous lesson to unlock this level!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Button {
                    DuoSound.playTap()
                    previewRoute = nil
                    activeLesson = route
                } label: {
                    Text("JUMP AHEAD ANYWAY")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(
                    Duo3DButtonStyle(
                        fill: Color(UIColor.systemBackground),
                        shadow: DuoColor.swanShadow,
                        foreground: DuoColor.hareGray
                    )
                )
            } else {
                Button {
                    DuoSound.playTap()
                    previewRoute = nil
                    activeLesson = route
                } label: {
                    Text(state == .completed ? "PRACTICE +\(meta.xpReward / 2) XP" : "START +\(meta.xpReward) XP")
                        .font(.subheadline.weight(.black))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(
                    Duo3DButtonStyle(
                        fill: .white,
                        shadow: Color.black.opacity(0.18),
                        foreground: state == .completed ? DuoColor.beeYellowShadow : palette.primary
                    )
                )
            }
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardShadow)
                    .offset(y: 4)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(state == .locked ? DuoColor.swanGray : .clear, lineWidth: 2)
                    )
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}
