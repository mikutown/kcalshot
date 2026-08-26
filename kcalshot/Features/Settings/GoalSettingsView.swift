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

    private let orangeDark = Color(red: 180.0/255, green: 118.0/255, blue: 0)
    private let coralDark = Color(red: 214.0/255, green: 74.0/255, blue: 42.0/255)

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
                    .tint(Color.inkTertiary)
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
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("每日目标热量")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkSecondary)
                            Text("维持热量 TDEE \(Int(goal.tdee.rounded())) kcal")
                                .font(.caption)
                                .foregroundStyle(Color.inkTertiary)
                        }
                        Spacer()
                        (Text("\(Int(goal.targetCalories.rounded()))")
                            .font(.system(size: 28, weight: .bold)).monospacedDigit()
                         + Text(" kcal").font(.subheadline).foregroundStyle(Color.inkTertiary))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    HStack(spacing: 10) {
                        macroChip("蛋白质", goal.protein, tint: .brandGreen, label: .brandGreenDeep)
                        macroChip("脂肪", goal.fat, tint: .brandCoral, label: coralDark)
                        macroChip("碳水", goal.carbs, tint: .brandOrange, label: orangeDark)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .tint(.brandGreen)
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
                    Button("完成") { dismiss() }.fontWeight(.bold)
                }
            }
        }
        .alert("如何选择活动水平", isPresented: $showActivityHelp) {
            Button("好", role: .cancel) {}
        } message: {
            Text(ActivityLevel.allCases.map { "· \($0.detail)" }.joined(separator: "\n"))
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

    private var heightBinding: Binding<Int> {
        Binding(get: { Int(goal.heightCm) }, set: { goal.heightCm = Double($0) })
    }

    private var weightBinding: Binding<Int> {
        Binding(get: { Int(goal.weightKg) }, set: { goal.weightKg = Double($0) })
    }

    private func wheelColumn(_ title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, unit: LocalizedStringKey) -> some View {
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
