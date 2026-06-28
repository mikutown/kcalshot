import Foundation

/// 高精度模式：把同一张照片的多次采样结果聚合为一条更稳健的结果。
/// 策略（保持诚实口径，不编造精度）：取总热量中位数，选最接近中位数的一条为基准；
/// 若各结果食物项按序对齐，则对每项营养密度取中位数细化；用结果离散度调节置信度。
enum RecognitionAggregator {
    static func aggregate(_ results: [RecognitionResult]) -> RecognitionResult? {
        guard let first = results.first else { return nil }
        guard results.count > 1 else { return first }

        let totals = results.map(\.totalCalories)
        let medianTotal = median(totals)

        // 选最接近中位数的结果作为基准，避免跨结果按名称对齐的脆弱合并。
        var base = results.min {
            abs($0.totalCalories - medianTotal) < abs($1.totalCalories - medianTotal)
        } ?? first

        // 食物项数与逐项名称一致时，对每项营养密度与克数取中位数细化。
        if itemsAligned(results) {
            for i in base.items.indices {
                base.items[i].grams = median(results.map { $0.items[i].grams })
                base.items[i].caloriesPer100g = median(results.map { $0.items[i].caloriesPer100g })
                base.items[i].proteinPer100g = median(results.map { $0.items[i].proteinPer100g })
                base.items[i].fatPer100g = median(results.map { $0.items[i].fatPer100g })
                base.items[i].carbsPer100g = median(results.map { $0.items[i].carbsPer100g })
            }
        }

        // 离散度：相对中位数的最大偏差。分歧大→压低置信度强制核对；高度一致→适度提升。
        let maxDev = totals.map { abs($0 - medianTotal) }.max() ?? 0
        let relSpread = medianTotal > 0 ? maxDev / medianTotal : 0
        if relSpread > 0.25 {
            base.recognitionConfidence = min(base.recognitionConfidence, 0.5)
        } else if relSpread < 0.10 {
            base.recognitionConfidence = max(base.recognitionConfidence, 0.85)
        }

        return base
    }

    /// 各结果食物项数相同，且逐项名称（去空白、忽略大小写）一致。
    private static func itemsAligned(_ results: [RecognitionResult]) -> Bool {
        guard let count = results.first?.items.count, count > 0 else { return false }
        guard results.allSatisfy({ $0.items.count == count }) else { return false }
        for i in 0..<count {
            let names = Set(results.map {
                $0.items[i].name.trimmingCharacters(in: .whitespaces).lowercased()
            })
            if names.count != 1 { return false }
        }
        return true
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
