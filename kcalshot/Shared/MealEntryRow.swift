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

    private var totals: NutritionTotals { NutritionTotals(entries) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(totals.calories.rounded()))")
                    .font(.system(size: 34, weight: .bold))
                Text("kcal").foregroundStyle(.secondary)
                Spacer()
                Text("\(entries.count) 条记录").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                macro("蛋白质", totals.protein)
                macro("脂肪", totals.fat)
                macro("碳水", totals.carbs)
            }
        }
        .padding(.vertical, 4)
    }

    private func macro(_ name: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))g").font(.subheadline.bold())
            Text(name).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
