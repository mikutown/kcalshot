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
                Label("建议核对份量与识别结果，确认后再保存", systemImage: "exclamationmark.triangle.fill")
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

            Section("营养（AI 估算，可修改）") {
                numberRow("热量", value: $entry.calories, unit: "kcal")
                numberRow("蛋白质", value: $entry.protein, unit: "g")
                numberRow("脂肪", value: $entry.fat, unit: "g")
                numberRow("碳水", value: $entry.carbs, unit: "g")
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
        .navigationTitle(isNew ? "保存记录" : "编辑记录")
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
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func numberRow(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func saveNew() {
        if entry.name.trimmingCharacters(in: .whitespaces).isEmpty {
            entry.name = entry.mealType.displayName
        }
        context.insert(entry)
        dismiss()
        onFinish?()
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
            entry: MealEntry(mealType: .breakfast, name: "炒饭、煎蛋、沙拉、牛奶",
                             calories: 650, protein: 28, fat: 33, carbs: 67, healthScore: 7),
            isNew: true,
            needsReview: true
        )
    }
    .modelContainer(PreviewData.container)
}
