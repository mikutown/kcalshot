import SwiftUI

struct MealEntryRow: View {
    let entry: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name.isEmpty ? entry.mealType.displayName : entry.name)
                    .lineLimit(1)
                Text("\(Int(entry.calories.rounded())) kcal · 蛋\(Int(entry.protein))/脂\(Int(entry.fat))/碳\(Int(entry.carbs))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.healthScore)")
                .font(.caption.bold())
                .padding(6)
                .background(HealthScore.color(entry.healthScore).opacity(0.18), in: Circle())
                .foregroundStyle(HealthScore.color(entry.healthScore))
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = entry.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 44, height: 44)
                .overlay { Image(systemName: "fork.knife").foregroundStyle(.secondary) }
        }
    }
}

struct DailySummaryCard: View {
    let entries: [MealEntry]
    var goal: DailyGoal?

    private var totals: NutritionTotals { NutritionTotals(entries) }
    private var hasGoal: Bool { (goal?.targetCalories ?? 0) > 0 }

    private var averageHealth: Int? {
        guard !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.healthScore }
        return Int((Double(sum) / Double(entries.count)).rounded())
    }

    var body: some View {
        VStack(spacing: 12) {
            calorieHeader
            if hasGoal, let goal {
                ProgressView(value: min(totals.calories / max(goal.targetCalories, 1), 1))
                    .tint(totals.calories > goal.targetCalories ? .red : .accentColor)
            }
            HStack(spacing: 12) {
                macro("蛋白质", totals.protein, goal?.protein)
                macro("脂肪", totals.fat, goal?.fat)
                macro("碳水", totals.carbs, goal?.carbs)
            }
            if let avg = averageHealth {
                HStack {
                    Text("今日健康均分").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(avg)/10")
                    Text(HealthScore.label(avg)).foregroundStyle(HealthScore.color(avg))
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private var calorieHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(Int(totals.calories.rounded()))")
                .font(.system(size: 34, weight: .bold))
            Text("kcal").foregroundStyle(.secondary)
            Spacer()
            if hasGoal, let goal {
                let remaining = goal.targetCalories - totals.calories
                Text(remaining >= 0
                     ? "剩余 \(Int(remaining.rounded())) kcal"
                     : "超出 \(Int((-remaining).rounded())) kcal")
                    .font(.subheadline)
                    .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
            } else {
                Text("\(entries.count) 条记录").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func macro(_ name: String, _ value: Double, _ target: Double?) -> some View {
        VStack(spacing: 4) {
            if let target, target > 0 {
                Text("\(Int(value.rounded()))/\(Int(target.rounded()))g").font(.subheadline.bold())
                ProgressView(value: min(value / target, 1)).tint(.accentColor)
            } else {
                Text("\(Int(value.rounded()))g").font(.subheadline.bold())
            }
            Text(name).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
