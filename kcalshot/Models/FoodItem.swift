import Foundation

/// 与某项外观易混的候选食物（携带自身营养，便于本地一键切换，无需重新联网识别）。
struct FoodAlternative: Codable, Equatable, Hashable {
    var name: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbsPer100g: Double
    var healthScore: Int
    var healthReason: String
}

/// 一种食物：以「克数 + 每 100g 营养密度」表示。
/// 用户只需确认/修改克数，热量与营养按比例换算。
/// 既用于识别结果，也持久化在 MealEntry。
struct FoodItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// 份量（克）——用户可调。
    var grams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbsPer100g: Double
    /// 该食物本身的健康程度 1...10（10 最健康）。
    var healthScore: Int
    /// 该食物健康评分的简短理由。
    var healthReason: String
    /// 外观易混时的其它候选；不易混则为空。用户可一键切换。
    var alternatives: [FoodAlternative]

    init(
        id: UUID = UUID(),
        name: String,
        grams: Double,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        carbsPer100g: Double,
        healthScore: Int = 5,
        healthReason: String = "",
        alternatives: [FoodAlternative] = []
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbsPer100g = carbsPer100g
        self.healthScore = healthScore
        self.healthReason = healthReason
        self.alternatives = alternatives
    }

    // 容错解码：老数据缺字段时取默认，避免崩溃。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        grams = (try? c.decode(Double.self, forKey: .grams)) ?? 100
        caloriesPer100g = (try? c.decode(Double.self, forKey: .caloriesPer100g)) ?? 0
        proteinPer100g = (try? c.decode(Double.self, forKey: .proteinPer100g)) ?? 0
        fatPer100g = (try? c.decode(Double.self, forKey: .fatPer100g)) ?? 0
        carbsPer100g = (try? c.decode(Double.self, forKey: .carbsPer100g)) ?? 0
        healthScore = (try? c.decode(Int.self, forKey: .healthScore)) ?? 5
        healthReason = (try? c.decode(String.self, forKey: .healthReason)) ?? ""
        alternatives = (try? c.decode([FoodAlternative].self, forKey: .alternatives)) ?? []
    }

    private var factor: Double { grams / 100 }
    var calories: Double { caloriesPer100g * factor }
    var protein: Double { proteinPer100g * factor }
    var fat: Double { fatPer100g * factor }
    var carbs: Double { carbsPer100g * factor }

    /// 选用第 index 个候选：换上其名称与营养（克数不变），原识别项回退到候选列表，便于来回切换。
    mutating func selectAlternative(at index: Int) {
        guard alternatives.indices.contains(index) else { return }
        let chosen = alternatives[index]
        let previous = FoodAlternative(
            name: name,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            fatPer100g: fatPer100g,
            carbsPer100g: carbsPer100g,
            healthScore: healthScore,
            healthReason: healthReason
        )
        name = chosen.name
        caloriesPer100g = chosen.caloriesPer100g
        proteinPer100g = chosen.proteinPer100g
        fatPer100g = chosen.fatPer100g
        carbsPer100g = chosen.carbsPer100g
        healthScore = chosen.healthScore
        healthReason = chosen.healthReason
        alternatives[index] = previous
    }
}

extension Array where Element == FoodItem {
    var totalCalories: Double { reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { reduce(0) { $0 + $1.protein } }
    var totalFat: Double { reduce(0) { $0 + $1.fat } }
    var totalCarbs: Double { reduce(0) { $0 + $1.carbs } }
}
