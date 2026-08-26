import SwiftUI
import SwiftData

/// 快速添加：多选收藏/最近吃过的食物到购物车，调整份量后一次保存。
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FavoriteFood.createdAt, order: .reverse) private var favorites: [FavoriteFood]
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]

    /// 新记录归属的日期。
    var targetDate: Date = .now
    @State private var mealType: MealType

    init(targetDate: Date = .now, targetMeal: MealType? = nil) {
        self.targetDate = targetDate
        _mealType = State(initialValue: targetMeal ?? .suggested())
    }

    /// 购物车：待添加项，用户可逐一调整克数。
    @State private var cart: [CartItem] = []

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

    /// 已收藏的食物名称集合，用于在收藏列表里隐藏已存在于购物车中的项。
    private var cartNames: Set<String> {
        Set(cart.map { $0.favorite.name.trimmingCharacters(in: .whitespaces).lowercased() })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // 餐次选择器
                    Picker("餐次", selection: $mealType) {
                        ForEach(MealType.orderedCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }

                    // ──── 购物车：待添加区 ────
                    if !cart.isEmpty {
                        Section {
                            ForEach(cart) { item in
                                cartRow(item)
                            }
                            .onDelete { deleteCartItems($0) }
                        } header: {
                            HStack {
                                Text("待添加")
                                Text("(\(cart.count) 项)").foregroundStyle(.secondary)
                            }
                        }
                    }

                    // ──── 空状态 ────
                    if favorites.isEmpty && recentMeals.isEmpty {
                        ContentUnavailableView(
                            "暂无可快速添加的内容",
                            systemImage: "star",
                            description: Text("在确认份量页给食物点星标即可收藏为常吃")
                        )
                    }

                    // ──── 常吃收藏 ────
                    if !favorites.isEmpty {
                        Section("常吃收藏") {
                            ForEach(favorites) { fav in
                                let inCart = cartNames.contains(fav.name.trimmingCharacters(in: .whitespaces).lowercased())
                                Button {
                                    if inCart {
                                        removeFromCart(fav)
                                    } else {
                                        addToCart(fav)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("\(fav.healthScore)")
                                            .font(.caption.bold())
                                            .frame(width: 22, height: 22)
                                            .background(HealthScore.color(fav.healthScore).opacity(0.18), in: Circle())
                                            .foregroundStyle(HealthScore.color(fav.healthScore))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(fav.name).lineLimit(1)
                                            Text("\(Int(fav.toFoodItem().calories.rounded())) kcal · \(Int(fav.defaultGrams))g")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: inCart ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundStyle(Color.brandGreen)
                                    }
                                }
                                .buttonStyle(.plain)
                                .opacity(inCart ? 0.6 : 1)
                            }
                        }
                    }

                    // ──── 最近吃过 ────
                    if !recentMeals.isEmpty {
                        Section("最近吃过") {
                            ForEach(recentMeals) { entry in
                                Button {
                                    addMealToCart(entry)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("\(entry.healthScore)")
                                            .font(.caption.bold())
                                            .frame(width: 22, height: 22)
                                            .background(HealthScore.color(entry.healthScore).opacity(0.18), in: Circle())
                                            .foregroundStyle(HealthScore.color(entry.healthScore))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name.isEmpty ? entry.mealType.displayName : entry.name)
                                                .lineLimit(1)
                                            Text("\(Int(entry.calories.rounded())) kcal · \(entry.items.count) 种食物")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(Color.brandGreen)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)

                // ──── 底部保存按钮 ────
                if !cart.isEmpty {
                    VStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Text("合计").foregroundStyle(Color.inkSecondary)
                            Text("\(Int(cartTotalCalories.rounded())) kcal")
                                .fontWeight(.bold)
                                .foregroundStyle(Color.inkPrimary)
                            Text("· \(cart.count) 项")
                                .foregroundStyle(Color.inkTertiary)
                            Spacer()
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 4)

                        Button(action: saveAll) {
                            Text("添加 \(cart.count) 项到「\(mealType.displayName)」")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(
                                    LinearGradient(colors: [.brandGreen, .brandGreenDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .shadow(color: Color.brandGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .navigationTitle("快速添加")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.brandGreen)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if !cart.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("清空", role: .destructive) { cart.removeAll() }
                    }
                }
            }
        }
    }

    // MARK: - 购物车单项

    private var cartTotalCalories: Double {
        cart.reduce(0) { $0 + $1.favorite.toFoodItem().calories * ($1.grams / $1.favorite.defaultGrams) }
    }

    private func cartRow(_ item: CartItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.favorite.name).font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text("份量")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("克", value: $cart[cartIndex(for: item.id)].grams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .font(.subheadline)
                    Text("g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(estimatedCalories(item).rounded())) kcal")
                    .font(.subheadline.weight(.medium))
                Text("每 100g \(Int(item.favorite.caloriesPer100g.rounded())) kcal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func cartIndex(for id: UUID) -> Int {
        cart.firstIndex(where: { $0.id == id }) ?? 0
    }

    private func estimatedCalories(_ item: CartItem) -> Double {
        item.favorite.caloriesPer100g * (item.grams / 100)
    }

    // MARK: - 购物车操作

    private func addToCart(_ fav: FavoriteFood) {
        withAnimation { cart.append(CartItem(favorite: fav)) }
    }

    private func removeFromCart(_ fav: FavoriteFood) {
        let key = fav.name.trimmingCharacters(in: .whitespaces).lowercased()
        withAnimation {
            cart.removeAll { $0.favorite.name.trimmingCharacters(in: .whitespaces).lowercased() == key }
        }
    }

    private func deleteCartItems(_ offsets: IndexSet) {
        withAnimation { cart.remove(atOffsets: offsets) }
    }

    /// 把最近吃过的整餐所有食物加到购物车（避免重复项）。
    private func addMealToCart(_ entry: MealEntry) {
        for item in entry.items {
            let key = item.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            // 已在购物车则跳过
            if cart.contains(where: {
                $0.favorite.name.trimmingCharacters(in: .whitespaces).lowercased() == key
            }) { continue }
            // 如果有对应的收藏，使用收藏的默认克数；否则保留原克数
            if let fav = favorites.first(where: {
                $0.name.trimmingCharacters(in: .whitespaces).lowercased() == key
            }) {
                cart.append(CartItem(favorite: fav))
            } else {
                // 没有收藏记录，创建一个临时 FavoriteFood 放入购物车
                let temp = FavoriteFood(from: item)
                cart.append(CartItem(favorite: temp, grams: item.grams))
            }
        }
    }

    // MARK: - 保存

    /// 将购物车所有项合并为一条 MealEntry 保存。
    private func saveAll() {
        guard !cart.isEmpty else { return }

        let foodItems = cart.map { item -> FoodItem in
            var food = item.favorite.toFoodItem()
            food.grams = item.grams
            return food
        }

        let avgScore = Int(round(Double(cart.reduce(0) { $0 + $1.favorite.healthScore }) / Double(cart.count)))
        let names = cart.map(\.favorite.name).joined(separator: "、")

        context.insert(MealEntry(
            date: targetDate,
            mealType: mealType,
            name: names,
            items: foodItems,
            healthScore: avgScore,
            healthReason: cart.map(\.favorite.healthReason).filter { !$0.isEmpty }.joined(separator: "；")
        ))
        dismiss()
    }
}

// MARK: - 购物车项模型

private struct CartItem: Identifiable {
    let id: UUID
    let favorite: FavoriteFood
    var grams: Double

    init(favorite: FavoriteFood, grams: Double? = nil) {
        self.id = UUID()
        self.favorite = favorite
        self.grams = grams ?? favorite.defaultGrams
    }
}

#Preview {
    QuickAddView()
        .modelContainer(PreviewData.container)
}
