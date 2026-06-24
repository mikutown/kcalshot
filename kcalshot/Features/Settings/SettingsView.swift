import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var models: [APIModelConfig]
    @Query private var goals: [DailyGoal]

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
                }
                Section("健康同步") {
                    LabeledContent("Apple 健康", value: "未开启")
                }
                Section("关于") {
                    LabeledContent("版本", value: "0.1.0 (M4)")
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
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
