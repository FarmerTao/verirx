import Foundation

/// Pure Swift FSRS v5 Spaced Repetition Scheduler with Exam-Date Cram Pacing.
/// Zero network calls, deterministic mathematical memory scheduling.
public struct FSRSScheduler {
    // Default FSRS v5 weights
    private let w: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105,
        7.1949, 0.5345, 1.4604, 0.0046,
        1.54575, 0.1192, 1.01925, 1.9395,
        0.11, 0.29605, 2.2698, 0.2315,
        2.9898, 0.51655, 0.6621
    ]

    private let desiredRetention: Double

    public init(desiredRetention: Double = 0.90) {
        self.desiredRetention = min(max(desiredRetention, 0.75), 0.97)
    }

    public func schedule(
        state: FSRSCardState,
        rating: FSRSRating,
        now: Date = Date(),
        examDate: Date? = nil
    ) -> FSRSCardState {
        var next = state
        let g = Double(rating.rawValue)

        if state.reps == 0 || state.lastReview == nil {
            // First review initialization
            next.stability = max(0.1, w[rating.rawValue - 1])
            let rawD = w[4] - exp(w[5] * (g - 1.0)) + 1.0
            next.difficulty = clampDifficulty(rawD)
        } else {
            let elapsedDays = max(0.01, now.timeIntervalSince(state.lastReview!) / 86_400.0)
            let retrievability = forgettingCurve(elapsedDays: elapsedDays, stability: state.stability)

            // Update Difficulty D
            let deltaD = -w[6] * (g - 3.0)
            let dampedD = state.difficulty + deltaD * ((10.0 - state.difficulty) / 9.0)
            let meanRevertedD = w[7] * w[4] + (1.0 - w[7]) * dampedD
            next.difficulty = clampDifficulty(meanRevertedD)

            // Update Stability S
            if rating == .again {
                next.lapses += 1
                let postLapseS = w[11]
                    * pow(next.difficulty, -w[12])
                    * (pow(state.stability + 1.0, w[13]) - 1.0)
                    * exp(w[14] * (1.0 - retrievability))
                next.stability = max(0.1, min(state.stability, postLapseS))
            } else {
                let hardPenalty = (rating == .hard) ? w[15] : 1.0
                let easyBonus = (rating == .easy) ? w[16] : 1.0
                let growth = exp(w[8])
                    * (11.0 - next.difficulty)
                    * pow(state.stability, -w[9])
                    * (exp(w[10] * (1.0 - retrievability)) - 1.0)
                    * hardPenalty
                    * easyBonus
                next.stability = max(0.2, state.stability * (1.0 + growth))
            }
        }

        next.reps += 1
        next.lastReview = now

        var intervalDays = nextIntervalDays(stability: next.stability, rating: rating)

        // Exam-Date Cram Compression: ensure cards rated Again/Hard/Good get seen before test day
        if let examDate = examDate {
            let daysUntilExam = examDate.timeIntervalSince(now) / 86_400.0
            if daysUntilExam > 1.0 && rating != .easy && intervalDays > daysUntilExam * 0.65 {
                intervalDays = max(0.5, daysUntilExam * 0.5)
            }
        }

        next.nextDue = now.addingTimeInterval(intervalDays * 86_400.0)
        return next
    }

    public func previewIntervalLabel(
        state: FSRSCardState,
        rating: FSRSRating,
        now: Date = Date(),
        examDate: Date? = nil
    ) -> String {
        let simulated = schedule(state: state, rating: rating, now: now, examDate: examDate)
        let seconds = simulated.nextDue.timeIntervalSince(now)
        let hours = seconds / 3600.0
        if hours < 1.0 {
            return "<15m"
        } else if hours < 24.0 {
            return "\(Int(round(hours)))h"
        } else {
            return "\(Int(round(hours / 24.0)))d"
        }
    }

    private func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        let factor = 19.0 / 81.0
        return pow(1.0 + factor * (elapsedDays / max(0.1, stability)), -0.5)
    }

    private func nextIntervalDays(stability: Double, rating: FSRSRating) -> Double {
        if rating == .again {
            return 10.0 / (24.0 * 60.0) // ~10 minutes intra-day relearn
        }
        let factor = 81.0 / 19.0
        let rawDays = stability * factor * (pow(desiredRetention, -2.0) - 1.0)
        return max(0.5, min(365.0, rawDays))
    }

    private func clampDifficulty(_ d: Double) -> Double {
        min(max(d, 1.0), 10.0)
    }
}
