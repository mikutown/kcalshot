import Foundation

/// 一组记录的营养合计。
struct NutritionTotals {
    var calories: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0

    init(_ entries: [MealEntry] = []) {
        for e in entries {
            calories += e.calories
            protein += e.protein
            fat += e.fat
            carbs += e.carbs
        }
    }
}

extension Array where Element == MealEntry {
    /// 当天（同一自然日）的记录。
    func onSameDay(as date: Date) -> [MealEntry] {
        let cal = Calendar.current
        return filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    /// 按餐次分组（保持固定顺序，空餐次省略）。
    func groupedByMeal() -> [(meal: MealType, entries: [MealEntry])] {
        MealType.orderedCases.compactMap { meal in
            let items = filter { $0.mealType == meal }
            return items.isEmpty ? nil : (meal, items.sorted { $0.date < $1.date })
        }
    }

    /// 按自然日分组，最近的日期在前。
    func groupedByDay() -> [(day: Date, entries: [MealEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: self) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date < $1.date }) }
    }
}
