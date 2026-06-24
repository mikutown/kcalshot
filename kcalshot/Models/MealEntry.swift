import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .snack: return "加餐"
        }
    }
}

@Model
final class MealEntry {
    var id: UUID
    var date: Date
    var mealTypeRaw: String
    var name: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    /// 1...10，10 = 最健康
    var healthScore: Int
    var note: String
    @Attribute(.externalStorage) var thumbnailData: Data?
    var modelUsed: String

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        mealType: MealType = .snack,
        name: String = "",
        calories: Double = 0,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        healthScore: Int = 5,
        note: String = "",
        thumbnailData: Data? = nil,
        modelUsed: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.name = name
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.healthScore = healthScore
        self.note = note
        self.thumbnailData = thumbnailData
        self.modelUsed = modelUsed
    }
}
