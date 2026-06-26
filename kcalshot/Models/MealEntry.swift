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
        case .breakfast: return String(localized: "早餐")
        case .lunch: return String(localized: "午餐")
        case .dinner: return String(localized: "晚餐")
        case .snack: return String(localized: "加餐")
        }
    }

    /// 按时段推断默认餐次。
    static func suggested(for date: Date = .now) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<10: return .breakfast
        case 10..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }

    /// 固定展示顺序。
    static let orderedCases: [MealType] = [.breakfast, .lunch, .dinner, .snack]
}

@Model
final class MealEntry {
    var id: UUID
    var date: Date
    var mealTypeRaw: String
    var name: String
    /// 分项明细（每项含克数与每 100g 营养）。
    var items: [FoodItem]
    // 以下为由 items 换算的缓存值，便于统计/查询；改动 items 后用 recomputeTotals() 同步。
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    /// 1...10，10 = 最健康
    var healthScore: Int
    /// 整餐健康评分的理由。
    var healthReason: String = ""
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
        items: [FoodItem] = [],
        calories: Double = 0,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        healthScore: Int = 5,
        healthReason: String = "",
        note: String = "",
        thumbnailData: Data? = nil,
        modelUsed: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.name = name
        self.items = items
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.healthScore = healthScore
        self.healthReason = healthReason
        self.note = note
        self.thumbnailData = thumbnailData
        self.modelUsed = modelUsed
        if !items.isEmpty { recomputeTotals() }
    }

    /// 由 items 的克数换算，刷新缓存的总热量与营养。
    func recomputeTotals() {
        calories = items.totalCalories
        protein = items.totalProtein
        fat = items.totalFat
        carbs = items.totalCarbs
    }
}
