import Core
import Foundation

public protocol CategoryEngineProviding {
    func classify(text: String) -> CategoryResult
    func classify(text: String, learnedCorrections: [CategoryCorrection]) -> CategoryResult
}

public extension CategoryEngineProviding {
    func classify(text: String) -> CategoryResult {
        classify(text: text, learnedCorrections: [])
    }
}

public struct KeywordCategoryEngine: CategoryEngineProviding {
    private let minimumLearningEvidence: Int
    private let dominanceThreshold: Double
    private let correctionHalfLifeDays: Double

    private let keywordMap: [DocumentCategory: [String]] = [
        .invoice: ["invoice", "vat", "total due", "bill to", "payment terms"],
        .contract: ["agreement", "party", "obligations", "contract", "terms and conditions"],
        .resume: ["curriculum vitae", "experience", "skills", "education", "resume"],
        .legal: ["plaintiff", "defendant", "court", "statute", "legal notice"],
        .medical: ["diagnosis", "prescription", "patient", "clinic", "medical report"],
        .education: ["transcript", "student", "course", "university", "grade"],
        .finance: ["statement", "account", "balance", "transaction", "iban"],
        .identification: ["passport", "id card", "date of birth", "nationality", "document number"],
        .correspondence: ["dear", "sincerely", "regards", "subject", "message"]
    ]

    public init(
        minimumLearningEvidence: Int = 2,
        dominanceThreshold: Double = 0.60,
        correctionHalfLifeDays: Double = 30
    ) {
        self.minimumLearningEvidence = max(1, minimumLearningEvidence)
        self.dominanceThreshold = min(max(0.0, dominanceThreshold), 1.0)
        self.correctionHalfLifeDays = max(1.0, correctionHalfLifeDays)
    }

    public func classify(text: String, learnedCorrections: [CategoryCorrection]) -> CategoryResult {
        let lower = text.lowercased()
        let tokens = Set(lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))

        var bestCategory: DocumentCategory = .general
        var bestScore = 0
        var bestMatchedKeyword = ""

        for (category, keywords) in keywordMap {
            var score = 0
            var matched = ""

            for keyword in keywords {
                if keyword.contains(" ") {
                    if lower.contains(keyword) {
                        score += 2
                        matched = keyword
                    }
                } else if tokens.contains(keyword) {
                    score += 1
                    matched = keyword
                }
            }

            if score > bestScore {
                bestScore = score
                bestCategory = category
                bestMatchedKeyword = matched
            }
        }

        if bestScore == 0 {
            return CategoryResult(
                category: .general,
                confidence: 0.25,
                explanation: "No strong category signals found, defaulted to general."
            )
        }

        let confidence = min(0.95, 0.45 + (Double(bestScore) * 0.12))
        let baseResult = CategoryResult(
            category: bestCategory,
            confidence: confidence,
            explanation: "Matched category signals such as '\(bestMatchedKeyword)'."
        )

        return applyCorrectionLearning(to: baseResult, learnedCorrections: learnedCorrections)
    }

    private func applyCorrectionLearning(
        to baseResult: CategoryResult,
        learnedCorrections: [CategoryCorrection]
    ) -> CategoryResult {
        let mapping = dominantCorrectionTarget(
            from: learnedCorrections,
            previousCategory: baseResult.category
        )

        guard
            let mappedCategory = mapping.category,
            mapping.supportingCount >= minimumLearningEvidence,
            mapping.dominance >= dominanceThreshold
        else {
            return baseResult
        }

        let adjustedConfidence = max(0.40, baseResult.confidence - 0.10)
        let dominanceText = String(format: "%.2f", mapping.dominance)
        return CategoryResult(
            category: mappedCategory,
            confidence: adjustedConfidence,
            explanation: "Adjusted by correction learning (\(mapping.supportingCount)/\(mapping.totalCount) supporting corrections, dominance \(dominanceText) from \(baseResult.category.rawValue) to \(mappedCategory.rawValue)). Base reason: \(baseResult.explanation)"
        )
    }

    private func dominantCorrectionTarget(
        from corrections: [CategoryCorrection],
        previousCategory: DocumentCategory
    ) -> (category: DocumentCategory?, supportingCount: Int, totalCount: Int, dominance: Double) {
        let filtered = corrections.filter { $0.previousCategory == previousCategory }
        guard !filtered.isEmpty else {
            return (nil, 0, 0, 0)
        }

        var weightedByTarget: [DocumentCategory: Double] = [:]
        var rawCountByTarget: [DocumentCategory: Int] = [:]
        for correction in filtered {
            weightedByTarget[correction.newCategory, default: 0] += recencyWeight(for: correction.correctedAt)
            rawCountByTarget[correction.newCategory, default: 0] += 1
        }

        let totalWeight = weightedByTarget.values.reduce(0, +)
        guard totalWeight > 0 else {
            return (nil, 0, filtered.count, 0)
        }

        let top = weightedByTarget.max { lhs, rhs in
            lhs.value < rhs.value
        }

        let dominance = (top?.value ?? 0) / totalWeight
        let topCategory = top?.key
        let supportingCount = topCategory.flatMap { rawCountByTarget[$0] } ?? 0
        return (topCategory, supportingCount, filtered.count, dominance)
    }

    private func recencyWeight(for correctedAt: Date) -> Double {
        let ageDays = max(0, Date().timeIntervalSince(correctedAt) / 86_400)
        let lambda = log(2) / correctionHalfLifeDays
        return exp(-lambda * ageDays)
    }
}
