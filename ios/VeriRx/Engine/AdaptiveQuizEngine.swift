import Foundation

/// Computerized Adaptive Testing (CAT) item selector & PTCE Scaled Readiness Estimator (1000–1600 scale).
public struct AdaptiveQuizEngine {
    public init() {}

    /// Computes domain ability theta in [1.0, 5.0] from historical question attempts.
    public func domainTheta(domainCode: String, attempts: [QuestionAttempt]) -> Double {
        let domainAttempts = attempts.filter { $0.domainCode == domainCode }
        guard !domainAttempts.isEmpty else { return 2.5 }

        var theta = 2.5
        for attempt in domainAttempts.suffix(30) {
            let itemDiff = Double(attempt.difficulty)
            // Logistic expected probability of correct response
            let expected = 1.0 / (1.0 + exp(-(theta - itemDiff)))
            let observed = attempt.isCorrect ? 1.0 : 0.0
            theta += 0.35 * (observed - expected)
            theta = min(max(theta, 1.0), 5.0)
        }
        return theta
    }

    /// Estimates PTCE scaled score (1000 to 1600; official passing score = 1400).
    public func estimatedScaledScore(domains: [ExamDomainInfo], attempts: [QuestionAttempt]) -> Int {
        guard !attempts.isEmpty else { return 1250 }
        var weightedTheta = 0.0
        var totalWeight = 0.0

        for domain in domains {
            let w = max(1.0, domain.weight_pct)
            weightedTheta += domainTheta(domainCode: domain.code, attempts: attempts) * w
            totalWeight += w
        }

        let avgTheta = totalWeight > 0 ? (weightedTheta / totalWeight) : 2.5
        // Map theta [1.0, 5.0] -> [1050, 1580], where theta=3.5 maps to ~1400 passing threshold
        let normalized = (avgTheta - 1.0) / 4.0
        let scaled = 1050.0 + normalized * 530.0
        return Int(min(max(round(scaled), 1000.0), 1600.0))
    }

    /// Selects an adaptive quiz session prioritizing weak domains and matching item difficulty to current theta.
    public func buildAdaptiveSession(
        pool: [QuestionItem],
        domains: [ExamDomainInfo],
        attempts: [QuestionAttempt],
        count: Int = 10
    ) -> [QuestionItem] {
        guard !pool.isEmpty else { return [] }

        let answeredCorrectlyIds = Set(attempts.filter(\.isCorrect).map(\.questionId))
        var selected: [QuestionItem] = []
        var usedIds = Set<String>()
        var simulatedThetaByDomain: [String: Double] = [:]

        for d in domains {
            simulatedThetaByDomain[d.code] = domainTheta(domainCode: d.code, attempts: attempts)
        }

        let targetCount = min(count, pool.count)
        for _ in 0..<targetCount {
            let candidates = pool.filter { !usedIds.contains($0.id) }
            guard !candidates.isEmpty else { break }

            // Score each candidate: prefer unseen or previously missed items near the learner's domain theta
            let best = candidates.min { a, b in
                scoreCandidate(a, thetas: simulatedThetaByDomain, mastered: answeredCorrectlyIds) <
                scoreCandidate(b, thetas: simulatedThetaByDomain, mastered: answeredCorrectlyIds)
            }

            if let chosen = best {
                selected.append(chosen)
                usedIds.insert(chosen.id)
            }
        }
        return selected
    }

    private func scoreCandidate(
        _ item: QuestionItem,
        thetas: [String: Double],
        mastered: Set<String>
    ) -> Double {
        let theta = thetas[item.domainCode] ?? 2.5
        let diffDistance = abs(Double(item.difficulty) - theta)
        let weakDomainBonus = (theta < 3.0) ? -0.4 : 0.0
        let alreadyMasteredPenalty = mastered.contains(item.id) ? 2.5 : 0.0
        return diffDistance + weakDomainBonus + alreadyMasteredPenalty
    }
}
