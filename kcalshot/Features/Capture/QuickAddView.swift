import SwiftUI
import SwiftData

/// 快速添加：从常吃收藏或最近吃过中一键再记录，不走 LLM。
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FavoriteFood.createdAt, order: .reverse) private var favorites: [FavoriteFood]
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]

    /// 新记录归属的日期。
    var targetDate: Date = .now
    @State private var mealType: MealType = .suggested()

    /// 最近吃过：按名称去重，取最近若干条。
    private var recentMeals: [MealEntry] {
        var seen = Set<String>()
        var result: [MealEntry] = []
        for entry in allEntries {
            let key = entry.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 20 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("餐次", selection: $mealType) {
                    ForEach(MealType.orderedCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }

                if favorites.isEmpty && recentMeals.isEmpty {
                    ContentUnavailableView(
                        "暂无可快速添加的内容",
                        systemImage: "star",
                        description: Text("在确认份量页给食物点星标即可收藏为常吃")
                    )
                }

                if !favorites.isEmpty {
                    Section("常吃收藏") {
                        ForEach(favorites) { fav in
                            Button { addFavorite(fav) } label: {
                                quickRow(
                                    name: fav.name,
                                    detail: "\(Int(fav.toFoodItem().calories.rounded())) kcal · \(Int(fav.defaultGrams))g",
                                    score: fav.healthScore
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !recentMeals.isEmpty {
                    Section("最近吃过") {
                        ForEach(recentMeals) { entry in
                            Button { addMeal(entry) } label: {
                                quickRow(
                                    name: entry.name.isEmpty ? entry.mealType.displayName : entry.name,
                                    detail: "\(Int(entry.calories.rounded())) kcal",
                                    score: entry.healthScore
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("快速添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func quickRow(name: String, detail: String, score: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(score)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(HealthScore.color(score).opacity(0.18), in: Circle())
                .foregroundStyle(HealthScore.color(score))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
        }
    }

    private func addFavorite(_ fav: FavoriteFood) {
        let item = fav.toFoodItem()
        context.insert(MealEntry(
            date: targetDate,
            mealType: mealType,
            name: fav.name,
            items: [item],
            healthScore: fav.healthScore,
            healthReason: fav.healthReason
        ))
        dismiss()
    }

    private func addMeal(_ entry: MealEntry) {
        context.insert(MealEntry(
            date: targetDate,
            mealType: mealType,
            name: entry.name,
            items: entry.items,
            healthScore: entry.healthScore,
            healthReason: entry.healthReason,
            thumbnailData: entry.thumbnailData,
            modelUsed: entry.modelUsed
        ))
        dismiss()
    }
}

#Preview {
    QuickAddView()
        .modelContainer(PreviewData.container)
}
