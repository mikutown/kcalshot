import SwiftUI
import SwiftData

struct GoalSettingsView: View {
    /// 作为 sheet 呈现（首次引导）时显示"完成"按钮。
    var showsDone: Bool = false

    @Environment(\.modelContext) private var context
    @Query private var goals: [DailyGoal]

    var body: some View {
        Group {
            if let goal = goals.first {
                GoalForm(goal: goal, showsDone: showsDone)
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
    var showsDone: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showActivityHelp = false

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
                .pickerStyle(.segmented)

                HStack(spacing: 0) {
                    wheelColumn("年龄", value: $goal.age, range: 10...100, unit: "岁")
                    wheelColumn("身高", value: heightBinding, range: 120...220, unit: "cm")
                    wheelColumn("体重", value: weightBinding, range: 30...200, unit: "kg")
                }
                .frame(height: 140)

                HStack {
                    Picker("活动水平", selection: $goal.activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) }
                    }
                    Button {
                        showActivityHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Section {
                LabeledContent("推荐每日热量", value: "\(Int(tdee.rounded())) kcal")
                Button("应用推荐值") { applyRecommended() }
            } footer: {
                Text("按 Mifflin-St Jeor 公式估算。应用后会覆盖下方目标，你仍可手动微调。")
            }

            Section("每日目标（可手动微调）") {
                Stepper(value: $goal.targetCalories, in: 800...5000, step: 10) {
                    LabeledContent("目标热量", value: "\(Int(goal.targetCalories.rounded())) kcal")
                }
                Stepper(value: $goal.protein, in: 0...400, step: 1) {
                    LabeledContent("蛋白质", value: "\(Int(goal.protein.rounded())) g")
                }
                Stepper(value: $goal.fat, in: 0...300, step: 1) {
                    LabeledContent("脂肪", value: "\(Int(goal.fat.rounded())) g")
                }
                Stepper(value: $goal.carbs, in: 0...600, step: 1) {
                    LabeledContent("碳水", value: "\(Int(goal.carbs.rounded())) g")
                }
            }
        }
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .alert("活动水平怎么选", isPresented: $showActivityHelp) {
            Button("好", role: .cancel) {}
        } message: {
            Text(ActivityLevel.allCases.map { "· \($0.detail)" }.joined(separator: "\n"))
        }
    }

    private var heightBinding: Binding<Int> {
        Binding(get: { Int(goal.heightCm) }, set: { goal.heightCm = Double($0) })
    }

    private var weightBinding: Binding<Int> {
        Binding(get: { Int(goal.weightKg) }, set: { goal.weightKg = Double($0) })
    }

    private func applyRecommended() {
        let calories = tdee.rounded()
        let macros = TDEECalculator.recommendedMacros(calories: calories)
        goal.targetCalories = calories
        goal.protein = macros.protein
        goal.fat = macros.fat
        goal.carbs = macros.carbs
    }

    private func wheelColumn(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Picker(title, selection: value) {
                ForEach(Array(range), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { GoalSettingsView() }
        .modelContainer(PreviewData.container)
}
