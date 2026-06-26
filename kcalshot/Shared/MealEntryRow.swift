import SwiftUI

struct MealEntryRow: View {
    let entry: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name.isEmpty ? entry.mealType.displayName : entry.name)
                    .lineLimit(1)
                Text("\(Int(entry.calories.rounded())) kcal · 蛋白\(Int(entry.protein))/脂\(Int(entry.fat))/碳\(Int(entry.carbs))")
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
    /// 当天活动消耗（kcal），加进可吃预算。
    var exercise: Double = 0

    private var totals: NutritionTotals { NutritionTotals(entries) }
    private var hasGoal: Bool { (goal?.targetCalories ?? 0) > 0 }
    private var target: Double { goal?.targetCalories ?? 0 }
    /// 当日预算 = 目标 + 运动消耗。
    private var budget: Double { target + exercise }
    private var remaining: Double { budget - totals.calories }
    private var isOver: Bool { remaining < 0 }

    private var averageHealth: Int? {
        guard !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.healthScore }
        return Int((Double(sum) / Double(entries.count)).rounded())
    }

    var body: some View {
        VStack(spacing: 16) {
            if hasGoal {
                budgetSection
            } else {
                noGoalHeader
            }
            HStack(spacing: 12) {
                macro("蛋白质", totals.protein, goal?.protein)
                macro("脂肪", totals.fat, goal?.fat)
                macro("碳水", totals.carbs, goal?.carbs)
            }
            if let avg = averageHealth {
                HStack {
                    Text("今日平均健康分").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(avg)/10")
                    Text(HealthScore.label(avg)).foregroundStyle(HealthScore.color(avg))
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private var budgetSection: some View {
        HStack(alignment: .center) {
            sideStat("饮食摄入", totals.calories)
            budgetRing
            sideStat("运动消耗", exercise)
        }
    }

    private var budgetRing: some View {
        ZStack {
            Circle().stroke(Color(.systemGray5), lineWidth: 9)
            Circle()
                .trim(from: 0, to: budget > 0 ? min(totals.calories / budget, 1) : 0)
                .stroke(isOver ? Color.red : Color.accentColor,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(isOver ? "超出（千卡）" : "剩余（千卡）")
                    .font(.caption2).foregroundStyle(.secondary)
                Text("\(Int(abs(remaining).rounded()))")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(isOver ? Color.red : Color.primary)
                Text("推荐预算 \(Int(target.rounded()))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 140, height: 140)
    }

    private func sideStat(_ title: LocalizedStringKey, _ value: Double) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(value.rounded()))").font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private var noGoalHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(Int(totals.calories.rounded()))")
                .font(.system(size: 34, weight: .bold))
            Text("kcal").foregroundStyle(.secondary)
            Spacer()
            Text("\(entries.count) 条记录").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func macro(_ name: LocalizedStringKey, _ value: Double, _ target: Double?) -> some View {
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
