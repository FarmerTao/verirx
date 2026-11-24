import SwiftUI

struct FlashcardSessionView: View {
    var studyStore: StudyStore
    let cards: [FlashcardItem]

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int = 0
    @State private var isFlipped: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            if index < cards.count {
                let card = cards[index]
                let state = studyStore.cardState(for: card.id)

                ProgressView(value: Double(index), total: Double(max(1, cards.count)))
                    .tint(.teal)
                    .padding(.horizontal)

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(card.domainCode.replacingOccurrences(of: "_", with: " "))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.teal.opacity(0.15), in: Capsule())
                            .foregroundStyle(.teal)
                        Spacer()
                        Text("\(index + 1) / \(cards.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(card.frontPrompt)
                        .font(.title3.weight(.semibold))
                        .padding(.top, 4)

                    if isFlipped {
                        Divider()
                        Text(card.backAnswer)
                            .font(.headline)
                            .foregroundStyle(.teal)

                        Text(card.backDetail)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        if let url = URL(string: card.citationUrl) {
                            Link(destination: url) {
                                Label(card.citationLabel, systemImage: "checkmark.seal.fill")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemBackground), in: Capsule())
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        Spacer().frame(height: 40)
                        Text("Tap card to reveal FDA-verified answer")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                .onTapGesture {
                    withAnimation(.spring(duration: 0.25)) {
                        isFlipped.toggle()
                    }
                }
                .padding(.horizontal)

                Spacer()

                if isFlipped {
                    HStack(spacing: 10) {
                        ForEach(FSRSRating.allCases, id: \.rawValue) { rating in
                            Button {
                                studyStore.recordFlashcardReview(cardId: card.id, rating: rating)
                                isFlipped = false
                                index += 1
                            } label: {
                                VStack(spacing: 4) {
                                    Text(rating.title)
                                        .font(.subheadline.bold())
                                    Text(
                                        studyStore.scheduler.previewIntervalLabel(
                                            state: state,
                                            rating: rating,
                                            examDate: studyStore.examDate
                                        )
                                    )
                                    .font(.caption2)
                                    .opacity(0.85)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(color(for: rating), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ContentUnavailableView(
                    "Session Complete!",
                    systemImage: "sparkles",
                    description: Text("FSRS has scheduled your next optimal review intervals.")
                )
                Button("Back to Today") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
            }
        }
        .padding(.vertical)
        .navigationTitle("FDA Flashcards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func color(for rating: FSRSRating) -> Color {
        switch rating {
        case .again: return .red
        case .hard: return .orange
        case .good: return .teal
        case .easy: return .indigo
        }
    }
}
