import Foundation
import SwiftData

/// 收藏的常吃食物：保存一份 FoodItem 的营养密度快照，便于快速复用、不走 LLM。
@Model
final class FavoriteFood {
    var id: UUID
    var name: String
    var defaultGrams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbsPer100g: Double
    var healthScore: Int
    var healthReason: String
    var createdAt: Date

    init(
        name: String,
        defaultGrams: Double,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        carbsPer100g: Double,
        healthScore: Int,
        healthReason: String,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.defaultGrams = defaultGrams
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbsPer100g = carbsPer100g
        self.healthScore = healthScore
        self.healthReason = healthReason
        self.createdAt = createdAt
    }

    convenience init(from item: FoodItem) {
        self.init(
            name: item.name,
            defaultGrams: item.grams,
            caloriesPer100g: item.caloriesPer100g,
            proteinPer100g: item.proteinPer100g,
            fatPer100g: item.fatPer100g,
            carbsPer100g: item.carbsPer100g,
            healthScore: item.healthScore,
            healthReason: item.healthReason
        )
    }

    func toFoodItem() -> FoodItem {
        FoodItem(
            name: name,
            grams: defaultGrams,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            fatPer100g: fatPer100g,
            carbsPer100g: carbsPer100g,
            healthScore: healthScore,
            healthReason: healthReason
        )
    }
}
