import Foundation
import SwiftData

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "男"
        case .female: return "女"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    /// TDEE = BMR * multiplier
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: return "久坐"
        case .light: return "轻度活动"
        case .moderate: return "中度活动"
        case .active: return "高度活动"
        case .veryActive: return "极高活动"
        }
    }
}

@Model
final class DailyGoal {
    var targetCalories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var sexRaw: String
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityRaw: String

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .sedentary }
        set { activityRaw = newValue.rawValue }
    }

    init(
        targetCalories: Double = 2000,
        protein: Double = 120,
        fat: Double = 60,
        carbs: Double = 220,
        sex: BiologicalSex = .male,
        age: Int = 30,
        heightCm: Double = 170,
        weightKg: Double = 65,
        activityLevel: ActivityLevel = .sedentary
    ) {
        self.targetCalories = targetCalories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.sexRaw = sex.rawValue
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityRaw = activityLevel.rawValue
    }
}
