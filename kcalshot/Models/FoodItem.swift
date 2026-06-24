import Foundation

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

    init(
        id: UUID = UUID(),
        name: String,
        grams: Double,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        carbsPer100g: Double
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbsPer100g = carbsPer100g
    }

    private var factor: Double { grams / 100 }
    var calories: Double { caloriesPer100g * factor }
    var protein: Double { proteinPer100g * factor }
    var fat: Double { fatPer100g * factor }
    var carbs: Double { carbsPer100g * factor }
}

extension Array where Element == FoodItem {
    var totalCalories: Double { reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { reduce(0) { $0 + $1.protein } }
    var totalFat: Double { reduce(0) { $0 + $1.fat } }
    var totalCarbs: Double { reduce(0) { $0 + $1.carbs } }
}
