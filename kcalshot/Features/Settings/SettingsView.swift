import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var models: [APIModelConfig]
    @Query private var goals: [DailyGoal]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    var body: some View {
        NavigationStack {
            List {
                Section("API & 模型") {
                    NavigationLink {
                        APISettingsView()
                    } label: {
                        LabeledContent("API 设置", value: globalSummary)
                    }
                    NavigationLink {
                        ModelListView()
                    } label: {
                        LabeledContent("模型管理", value: modelSummary)
                    }
                }
                Section("每日目标") {
                    NavigationLink {
                        GoalSettingsView()
                    } label: {
                        LabeledContent("目标热量", value: goalSummary)
                    }
                    NavigationLink {
                        WeightLogView()
                    } label: {
                        LabeledContent("体重记录", value: weightSummary)
                    }
                }
                Section {
                    Toggle("同步到 Apple 健康", isOn: healthToggle)
                        .disabled(!HealthKitManager.isAvailable)
                } header: {
                    Text("健康同步")
                } footer: {
                    Text(HealthKitManager.isAvailable
                         ? "开启后，每日摄入总热量会写入 Apple 健康；并读取活动消耗计入今天预算、读取体重用于体重趋势。"
                         : "此设备不支持 HealthKit。")
                }
                Section("关于") {
                    NavigationLink {
                        PrivacyInfoView()
                    } label: {
                        Text("数据与隐私")
                    }
                    LabeledContent("版本", value: "0.1.0 (M5)")
                }
            }
            .navigationTitle("设置")
        }
    }

    private var globalSummary: String {
        settings.globalBaseURL.isEmpty ? "未配置" : "已配置"
    }

    private var modelSummary: String {
        models.isEmpty ? "0 个" : "\(models.count) 个"
    }

    private var goalSummary: String {
        if let goal = goals.first, goal.targetCalories > 0 {
            return "\(Int(goal.targetCalories.rounded())) kcal"
        }
        return "未设置"
    }

    private var weightSummary: String {
        guard let latest = weights.first else { return "未记录" }
        return String(format: "%.1f kg", latest.weightKg)
    }

    private var healthToggle: Binding<Bool> {
        Binding(
            get: { settings.healthSyncEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        settings.healthSyncEnabled = await HealthKitManager.requestAuthorization()
                    }
                } else {
                    settings.healthSyncEnabled = false
                }
            }
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
