import SwiftUI
import SwiftData

struct MealEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: MealEntry
    var isNew: Bool
    var needsReview: Bool = false
    /// 保存/删除后回调（用于关闭外层识别流程）。
    var onFinish: (() -> Void)?

    @Query private var favorites: [FavoriteFood]
    @State private var reasonPopup: String?

    private let orangeDark = Color(red: 180.0/255, green: 118.0/255, blue: 0)
    private let coralDark = Color(red: 214.0/255, green: 74.0/255, blue: 42.0/255)

    var body: some View {
        Form {
            if needsReview {
                Label("请核对每种食物的份量（克），确认后保存", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(orangeDark)
                    .listRowBackground(Color.brandOrange.opacity(0.14))
            }

            if let data = entry.thumbnailData, let image = UIImage(data: data) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                }
            }

            summarySection

            Section("餐次与名称") {
                DatePicker("日期", selection: $entry.date, displayedComponents: [.date, .hourAndMinute])
                Picker("餐次", selection: $entry.mealType) {
                    ForEach(MealType.orderedCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
                TextField("名称", text: $entry.name, axis: .vertical)
            }

            Section {
                if entry.items.isEmpty {
                    Text("此记录无分项明细").foregroundStyle(Color.inkTertiary)
                } else {
                    ForEach($entry.items) { $item in
                        itemEditor($item)
                    }
                    .onDelete(perform: deleteItems)
                }
            } header: {
                Text("食物份量（调整克数，热量自动换算）")
            } footer: {
                Text("营养密度（每 100g）由 AI 估算，仅需核对克数。")
            }

            Section("整餐健康评分") {
                HStack(spacing: 10) {
                    healthBadge(entry.healthScore)
                    Button {
                        showReason(entry.healthReason)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .tint(Color.inkTertiary)
                    Spacer()
                    Text("由 AI 评定").font(.caption).foregroundStyle(Color.inkTertiary)
                }
            }

            Section("备注") {
                TextField("可选", text: $entry.note, axis: .vertical)
            }

            if !isNew {
                Section {
                    Button("删除这条记录", role: .destructive, action: deleteEntry)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .tint(.brandGreen)
        .navigationTitle(isNew ? "确认份量" : "编辑记录")
        .navigationBarTitleDisplayMode(.inline)
        .alert("评分理由", isPresented: Binding(
            get: { reasonPopup != nil },
            set: { if !$0 { reasonPopup = nil } }
        ), presenting: reasonPopup) { _ in
            Button("好", role: .cancel) {}
        } message: { reason in
            Text(reason)
        }
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: saveNew).fontWeight(.bold)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: finishEdit).fontWeight(.bold)
                }
            }
        }
    }

    // MARK: - 合计

    private var summarySection: some View {
        Section {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("这一餐合计")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    (Text("\(Int(entry.items.totalCalories.rounded()))")
                        .font(.system(size: 28, weight: .bold)).monospacedDigit()
                     + Text(" kcal").font(.subheadline).foregroundStyle(Color.inkTertiary))
                        .foregroundStyle(Color.inkPrimary)
                }
                HStack(spacing: 10) {
                    macroChip("蛋白质", entry.items.totalProtein, tint: .brandGreen, label: .brandGreenDeep)
                    macroChip("脂肪", entry.items.totalFat, tint: .brandCoral, label: coralDark)
                    macroChip("碳水", entry.items.totalCarbs, tint: .brandOrange, label: orangeDark)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func macroChip(_ name: String, _ value: Double, tint: Color, label: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))g")
                .font(.system(size: 16, weight: .heavy)).monospacedDigit()
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func healthBadge(_ score: Int) -> some View {
        let color = HealthScore.color(score)
        return HStack(spacing: 5) {
            Text("\(score)/10").font(.subheadline.weight(.heavy)).monospacedDigit()
            Text(HealthScore.label(score)).font(.caption.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }

    // MARK: - 分项编辑

    private func itemEditor(_ item: Binding<FoodItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("名称", text: item.name)
                .font(.subheadline.weight(.semibold))
            HStack {
                Text("份量").foregroundStyle(Color.inkSecondary)
                TextField("克", value: item.grams, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                Text("g").foregroundStyle(Color.inkTertiary)
                Spacer()
                Text("\(Int(item.wrappedValue.calories.rounded())) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandGreenDeep)
            }
            HStack(spacing: 6) {
                Text("健康评分").foregroundStyle(Color.inkTertiary)
                Text("\(item.wrappedValue.healthScore)/10")
                    .fontWeight(.semibold)
                Text(HealthScore.label(item.wrappedValue.healthScore))
                    .foregroundStyle(HealthScore.color(item.wrappedValue.healthScore))
                Button {
                    showReason(item.wrappedValue.healthReason)
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .tint(Color.inkTertiary)
                Spacer()
                Button {
                    toggleFavorite(item.wrappedValue)
                } label: {
                    Image(systemName: isFavorited(item.wrappedValue) ? "star.fill" : "star")
                        .foregroundStyle(isFavorited(item.wrappedValue) ? Color.brandOrange : Color.inkTertiary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isFavorited(item.wrappedValue) ? "取消收藏" : "收藏为常吃")
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func isFavorited(_ item: FoodItem) -> Bool {
        let key = item.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return false }
        return favorites.contains { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == key }
    }

    private func toggleFavorite(_ item: FoodItem) {
        let key = item.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return }
        if let existing = favorites.first(where: {
            $0.name.trimmingCharacters(in: .whitespaces).lowercased() == key
        }) {
            context.delete(existing)
        } else {
            context.insert(FavoriteFood(from: item))
        }
    }

    private func showReason(_ text: String) {
        reasonPopup = text.isEmpty ? String(localized: "（暂无说明）") : text
    }

    private func deleteItems(_ offsets: IndexSet) {
        entry.items.remove(atOffsets: offsets)
        entry.recomputeTotals()
    }

    private func saveNew() {
        if entry.name.trimmingCharacters(in: .whitespaces).isEmpty {
            entry.name = entry.items.map(\.name).joined(separator: "、")
        }
        entry.recomputeTotals()
        context.insert(entry)
        dismiss()
        onFinish?()
    }

    private func finishEdit() {
        entry.recomputeTotals()
        dismiss()
    }

    private func deleteEntry() {
        context.delete(entry)
        dismiss()
        onFinish?()
    }
}

#Preview {
    NavigationStack {
        MealEditView(
            entry: MealEntry(
                mealType: .breakfast,
                name: "炒饭、煎蛋、牛奶",
                items: [
                    FoodItem(name: "炒饭", grams: 250, caloriesPer100g: 140, proteinPer100g: 5, fatPer100g: 5.5, carbsPer100g: 19),
                    FoodItem(name: "煎蛋", grams: 50, caloriesPer100g: 180, proteinPer100g: 13, fatPer100g: 14, carbsPer100g: 1),
                    FoodItem(name: "牛奶", grams: 250, caloriesPer100g: 60, proteinPer100g: 3.2, fatPer100g: 3.2, carbsPer100g: 4.8),
                ],
                healthScore: 7
            ),
            isNew: true,
            needsReview: true
        )
    }
    .modelContainer(PreviewData.container)
}
