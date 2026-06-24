import Foundation

/// 基础代谢与每日消耗计算（Mifflin-St Jeor），以及营养目标推荐。
enum TDEECalculator {
    /// 基础代谢率 BMR（kcal/天）。
    static func bmr(sex: BiologicalSex, age: Int, heightCm: Double, weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return base + (sex == .male ? 5 : -161)
    }

    /// 每日总消耗 TDEE = BMR × 活动系数。
    static func tdee(sex: BiologicalSex, age: Int, heightCm: Double, weightKg: Double, activity: ActivityLevel) -> Double {
        bmr(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg) * activity.multiplier
    }

    /// 由目标热量与目标类型推荐三大营养素克数（配比随目标变）。
    static func recommendedMacros(calories: Double, goalType: GoalType) -> (protein: Double, fat: Double, carbs: Double) {
        let split = goalType.macroSplit
        let protein = calories * split.protein / 4
        let fat = calories * split.fat / 9
        let carbs = calories * split.carbs / 4
        return (protein.rounded(), fat.rounded(), carbs.rounded())
    }
}
