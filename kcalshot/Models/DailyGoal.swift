import Foundation
import SwiftData

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case cut
    case maintain
    case bulk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cut: return "减脂"
        case .maintain: return "维持"
        case .bulk: return "增肌"
        }
    }

    /// 默认热量调整比例（相对 TDEE）。
    var defaultFactor: Double {
        switch self {
        case .cut: return -0.20
        case .maintain: return 0
        case .bulk: return 0.10
        }
    }

    /// 缺口/盈余可调范围（signed kcal）。维持恒为 0。
    var deltaRange: ClosedRange<Double> {
        switch self {
        case .cut: return -800 ... -100
        case .maintain: return 0 ... 0
        case .bulk: return 100 ... 600
        }
    }

    /// 营养配比（蛋白/脂肪/碳水 占热量比例）。
    var macroSplit: (protein: Double, fat: Double, carbs: Double) {
        switch self {
        case .cut: return (0.35, 0.30, 0.35)
        case .maintain: return (0.25, 0.30, 0.45)
        case .bulk: return (0.30, 0.25, 0.45)
        }
    }
}

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

    var detail: String {
        switch self {
        case .sedentary: return "几乎不运动，以坐姿办公/在家为主（系数 1.2）"
        case .light: return "每周轻度运动 1–3 天，或日常步行较多（系数 1.375）"
        case .moderate: return "每周中等强度运动 3–5 天（系数 1.55）"
        case .active: return "每周高强度运动 6–7 天（系数 1.725）"
        case .veryActive: return "体力劳动，或每天高强度训练（系数 1.9）"
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
    var goalTypeRaw: String = GoalType.maintain.rawValue
    /// 相对 TDEE 的热量缺口/盈余（signed kcal）。
    var calorieDelta: Double = 0

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .sedentary }
        set { activityRaw = newValue.rawValue }
    }

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .maintain }
        set { goalTypeRaw = newValue.rawValue }
    }

    /// 维持热量（TDEE）。
    var tdee: Double {
        TDEECalculator.tdee(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg, activity: activityLevel)
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
        activityLevel: ActivityLevel = .sedentary,
        goalType: GoalType = .maintain,
        calorieDelta: Double = 0
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
        self.goalTypeRaw = goalType.rawValue
        self.calorieDelta = calorieDelta
    }

    /// 把目标类型的默认缺口/盈余套用到 calorieDelta（按当前 TDEE）。
    func resetDeltaToDefault() {
        let raw = tdee * goalType.defaultFactor
        let range = goalType.deltaRange
        calorieDelta = min(max(raw.rounded(), range.lowerBound), range.upperBound)
    }

    /// 由身体数据 + 目标类型 + 缺口/盈余，重算目标热量与三大营养。
    func recompute() {
        targetCalories = max((tdee + calorieDelta).rounded(), 0)
        let macros = TDEECalculator.recommendedMacros(calories: targetCalories, goalType: goalType)
        protein = macros.protein
        fat = macros.fat
        carbs = macros.carbs
    }
}
