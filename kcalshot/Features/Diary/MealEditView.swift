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

    var body: some View {
        Form {
            if needsReview {
                Label("核对每种食物的份量（克），确认后再保存", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .listRowBackground(Color.orange.opacity(0.12))
            }

            if let data = entry.thumbnailData, let image = UIImage(data: data) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)
                }
            }

            Section("餐次与名称") {
                Picker("餐次", selection: $entry.mealType) {
                    ForEach(MealType.orderedCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
                TextField("名称", text: $entry.name, axis: .vertical)
            }

            Section {
                if entry.items.isEmpty {
                    Text("此记录无分项明细").foregroundStyle(.secondary)
                } else {
                    ForEach($entry.items) { $item in
                        itemEditor($item)
                    }
                    .onDelete(perform: deleteItems)
                }
            } header: {
                Text("食物份量（调整克数，热量自动换算）")
            } footer: {
                Text("营养密度（每 100g）来自 AI 估算；你只需核对克数。")
            }

            Section("这一餐合计") {
                LabeledContent("热量", value: "\(Int(entry.items.totalCalories.rounded())) kcal")
                LabeledContent("蛋白质", value: "\(Int(entry.items.totalProtein.rounded())) g")
                LabeledContent("脂肪", value: "\(Int(entry.items.totalFat.rounded())) g")
                LabeledContent("碳水", value: "\(Int(entry.items.totalCarbs.rounded())) g")
            }

            Section("健康评分") {
                Stepper(value: $entry.healthScore, in: 1...10) {
                    HStack {
                        Text("\(entry.healthScore)/10")
                        Text(HealthScore.label(entry.healthScore))
                            .foregroundStyle(HealthScore.color(entry.healthScore))
                    }
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
        .navigationTitle(isNew ? "确认份量" : "编辑记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: saveNew)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: finishEdit)
                }
            }
        }
    }

    private func itemEditor(_ item: Binding<FoodItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("名称", text: item.name)
            HStack {
                Text("份量")
                TextField("克", value: item.grams, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                Text("g").foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(item.wrappedValue.calories.rounded())) kcal")
                    .font(.subheadline.weight(.medium))
            }
        }
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
