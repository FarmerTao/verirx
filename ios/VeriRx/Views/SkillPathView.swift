import SwiftUI

struct SelectedLessonRoute: Identifiable, Hashable {
    let unit: SkillUnit
    let step: Int
    var id: String { "\(unit.id)-\(step)" }
}

struct SkillPathView: View {
    @Bindable var studyStore: StudyStore
    @State private var activeLesson: SelectedLessonRoute?

    var body: some View {
        VStack(spacing: 0) {
            topGamifiedHUD
            Divider()

            ScrollView {
                VStack(spacing: 28) {
                    dailyGoalCard

                    ForEach(studyStore.skillUnits) { unit in
                        unitSection(unit)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $activeLesson) { route in
            DuolingoLessonView(
                studyStore: studyStore,
                unit: route.unit,
                step: route.step
            )
        }
    }

    private var topGamifiedHUD: some View {
        HStack(spacing: 18) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(studyStore.streakDays)")
                    .font(.headline.monospacedDigit())
            }

            HStack(spacing: 5) {
                Image(systemName: "snowflake")
                    .foregroundStyle(.cyan)
                Text("\(studyStore.streakFreezes)")
                    .font(.subheadline.bold().monospacedDigit())
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("\(studyStore.totalXP) XP")
                    .font(.headline.monospacedDigit())
            }

            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.teal)
                Text("\(studyStore.readinessScore)")
                    .font(.subheadline.bold().monospacedDigit())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var dailyGoalCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DAILY QUEST")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.teal)
                    Spacer()
                    Text("\(min(studyStore.todayXP, studyStore.dailyGoalXP)) / \(studyStore.dailyGoalXP) XP")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                ProgressView(
                    value: Double(min(studyStore.todayXP, studyStore.dailyGoalXP)),
                    total: Double(studyStore.dailyGoalXP)
                )
                .tint(.teal)

                if !studyStore.dueFlashcards.isEmpty {
                    NavigationLink {
                        FlashcardSessionView(
                            studyStore: studyStore,
                            cards: studyStore.dueFlashcards
                        )
                    } label: {
                        Label("Warm-up: \(studyStore.dueFlashcards.count) FSRS cards due →", systemImage: "dumbbell.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.teal)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }

    private func unitSection(_ unit: SkillUnit) -> some View {
        let tint = themeColor(unit.themeColor)
        return VStack(spacing: 22) {
            // Duolingo-style Unit Banner
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Text(unit.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.92))
                }
                Spacer()
                Image(systemName: unit.iconName)
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            // Winding S-Curve 3-Node Path per Unit
            VStack(spacing: 18) {
                pathNodeButton(
                    unit: unit,
                    step: 1,
                    label: "Roots & Match",
                    icon: "puzzlepiece.fill",
                    xOffset: -44,
                    tint: tint
                )
                pathNodeButton(
                    unit: unit,
                    step: 2,
                    label: "Sig Builder",
                    icon: "text.bubble.fill",
                    xOffset: 44,
                    tint: tint
                )
                pathNodeButton(
                    unit: unit,
                    step: 3,
                    label: "Boss Challenge",
                    icon: "crown.fill",
                    xOffset: 0,
                    tint: tint
                )
            }
        }
    }

    private func pathNodeButton(
        unit: SkillUnit,
        step: Int,
        label: String,
        icon: String,
        xOffset: CGFloat,
        tint: Color
    ) -> some View {
        let done = studyStore.isNodeCompleted(unit: unit, step: step)
        return Button {
            activeLesson = SelectedLessonRoute(unit: unit, step: step)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(done ? Color.yellow.opacity(0.25) : tint.opacity(0.18))
                        .frame(width: 84, height: 84)

                    Circle()
                        .fill(done ? Color.yellow.gradient : tint.gradient)
                        .frame(width: 68, height: 68)
                        .shadow(color: (done ? Color.orange : tint).opacity(0.45), radius: 0, x: 0, y: 5)

                    Image(systemName: done ? "checkmark.seal.fill" : icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .offset(x: xOffset)
    }

    private func themeColor(_ name: String) -> Color {
        switch name {
        case "indigo": return .indigo
        case "emerald": return .green
        case "rose": return .pink
        case "purple": return .purple
        case "orange": return .orange
        default: return .teal
        }
    }
}
