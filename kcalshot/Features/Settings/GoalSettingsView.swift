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

    private var bodyKey: String {
        "\(goal.sexRaw)-\(goal.age)-\(goal.heightCm)-\(goal.weightKg)-\(goal.activityRaw)-\(goal.calorieDelta)"
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
                Picker("目标", selection: $goal.goalType) {
                    ForEach(GoalType.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                if goal.goalType != .maintain {
                    Stepper(value: $goal.calorieDelta, in: goal.goalType.deltaRange, step: 50) {
                        LabeledContent(
                            goal.goalType == .cut ? "热量缺口" : "热量盈余",
                            value: "\(Int(abs(goal.calorieDelta).rounded())) kcal"
                        )
                    }
                }
            } header: {
                Text("目标")
            } footer: {
                Text("目标热量 = 维持热量（TDEE）+ 缺口/盈余，营养配比随目标自动调整；切换阶段后将自动重算。")
            }

            Section("目标结果") {
                LabeledContent("维持热量 TDEE", value: "\(Int(goal.tdee.rounded())) kcal")
                LabeledContent("每日目标热量", value: "\(Int(goal.targetCalories.rounded())) kcal")
                LabeledContent("蛋白质", value: "\(Int(goal.protein.rounded())) g")
                LabeledContent("脂肪", value: "\(Int(goal.fat.rounded())) g")
                LabeledContent("碳水", value: "\(Int(goal.carbs.rounded())) g")
            }
        }
        .onAppear { goal.recompute() }
        .onChange(of: goal.goalType) { _, _ in
            goal.resetDeltaToDefault()
            goal.recompute()
        }
        .onChange(of: bodyKey) { _, _ in
            goal.recompute()
        }
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .alert("如何选择活动水平", isPresented: $showActivityHelp) {
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
