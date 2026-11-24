import SwiftUI

struct QuizSessionView: View {
    let title: String
    var studyStore: StudyStore
    let questions: [QuestionItem]

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int = 0
    @State private var selectedChoiceId: String? = nil
    @State private var correctCount: Int = 0

    var body: some View {
        ScrollView {
            if questions.isEmpty {
                ContentUnavailableView(
                    "No Questions in Filter",
                    systemImage: "doc.questionmark",
                    description: Text("Unlock VeriRx Pro or change domain filter.")
                )
                .padding(.top, 60)
            } else if index < questions.count {
                let q = questions[index]
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("\(q.domainCode.replacingOccurrences(of: "_", with: " ")) · Diff \(q.difficulty)/5")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.teal)
                        Spacer()
                        Text("Q \(index + 1) of \(questions.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(q.stem)
                        .font(.body.weight(.medium))
                        .lineSpacing(3)

                    VStack(spacing: 10) {
                        ForEach(q.choices) { choice in
                            choiceRow(choice: choice, question: q)
                        }
                    }

                    if selectedChoiceId != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Step-by-Step Explanation", systemImage: "lightbulb.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.teal)

                            Text(q.explanation)
                                .font(.subheadline)

                            Divider()

                            Text(q.citationQuote)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let url = URL(string: q.citationUrl) {
                                Link(destination: url) {
                                    Label("Verify Official Source / FDA SPL Label ↗", systemImage: "checkmark.shield.fill")
                                        .font(.caption.bold())
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                        Button {
                            selectedChoiceId = nil
                            index += 1
                        } label: {
                            Text(index + 1 < questions.count ? "Next Question" : "Finish Session")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.teal, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.teal)
                    Text("Session Score: \(correctCount) / \(questions.count)")
                        .font(.title2.bold())
                    Text("Updated Estimated PTCE Readiness: \(studyStore.readinessScore) / 1600")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                }
                .padding(.top, 80)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func choiceRow(choice: ChoiceOption, question: QuestionItem) -> some View {
        let isAnswered = selectedChoiceId != nil
        let isCorrect = choice.id == question.correctChoiceId
        let isSelected = choice.id == selectedChoiceId

        let borderColor: Color = {
            guard isAnswered else { return Color(.separator) }
            if isCorrect { return .green }
            if isSelected { return .red }
            return Color(.separator).opacity(0.4)
        }()

        return Button {
            guard selectedChoiceId == nil else { return }
            selectedChoiceId = choice.id
            if choice.id == question.correctChoiceId {
                correctCount += 1
            }
            studyStore.recordQuestionAttempt(question: question, selectedChoiceId: choice.id)
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
                if isAnswered {
                    Text(choice.rationale)
                        .font(.caption)
                        .foregroundStyle(isCorrect ? .green : .secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 2)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isAnswered && (isCorrect || isSelected) ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
