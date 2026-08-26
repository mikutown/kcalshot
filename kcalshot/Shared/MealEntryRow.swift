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
