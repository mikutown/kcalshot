import SwiftUI
import SwiftData

struct GoalSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [DailyGoal]

    var body: some View {
        Group {
            if let goal = goals.first {
                GoalForm(goal: goal)
            } else {
                ProgressView()
                    .onAppear { context.insert(DailyGoal()) }
            }
        }
        .navigationTitle("每日目标")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GoalForm: View {
    @Bindable var goal: DailyGoal

    private var tdee: Double {
        TDEECalculator.tdee(
            sex: goal.sex, age: goal.age,
            heightCm: goal.heightCm, weightKg: goal.weightKg,
            activity: goal.activityLevel
        )
    }

    var body: some View {
        Form {
            Section("身体数据") {
                Picker("性别", selection: $goal.sex) {
                    ForEach(BiologicalSex.allCases) { Text($0.displayName).tag($0) }
                }
                numberRow("年龄", value: ageBinding, unit: "岁")
                numberRow("身高", value: $goal.heightCm, unit: "cm")
                numberRow("体重", value: $goal.weightKg, unit: "kg")
                Picker("活动水平", selection: $goal.activityLevel) {
                    ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
                }
            }

            Section {
                LabeledContent("推荐每日热量", value: "\(Int(tdee.rounded())) kcal")
                Button("应用推荐值") { applyRecommended() }
            } footer: {
                Text("按 Mifflin-St Jeor 公式估算。应用后会覆盖下方目标，你仍可手动微调。")
            }

            Section("每日目标（可手动修改）") {
                numberRow("目标热量", value: $goal.targetCalories, unit: "kcal")
                numberRow("蛋白质", value: $goal.protein, unit: "g")
                numberRow("脂肪", value: $goal.fat, unit: "g")
                numberRow("碳水", value: $goal.carbs, unit: "g")
            }
        }
    }

    private var ageBinding: Binding<Double> {
        Binding(get: { Double(goal.age) }, set: { goal.age = Int($0) })
    }

    private func applyRecommended() {
        let calories = tdee.rounded()
        let macros = TDEECalculator.recommendedMacros(calories: calories)
        goal.targetCalories = calories
        goal.protein = macros.protein
        goal.fat = macros.fat
        goal.carbs = macros.carbs
    }

    private func numberRow(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { GoalSettingsView() }
        .modelContainer(PreviewData.container)
}
