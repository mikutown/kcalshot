import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var models: [APIModelConfig]
    @Query private var goals: [DailyGoal]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var waters: [WaterEntry]
    @Query private var tokenRecords: [TokenUsage]

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
                Section {
                    Toggle("高精度模式", isOn: highPrecision)
                    if settings.highPrecisionMode {
                        Stepper(value: precisionSamples, in: 2...5) {
                            LabeledContent("采样次数", value: "\(settings.precisionSampleCount)")
                        }
                    }
                    NavigationLink {
                        TokenUsageView()
                    } label: {
                        LabeledContent("Token 用量", value: tokenSummary)
                    }
                } header: {
                    Text("识别")
                } footer: {
                    Text("开启后，每次识别会对同一张照片多次采样并取中位数，准确度更稳但 API 成本与耗时按采样次数成倍增加（识别失败会自动重试，实际请求可能更多）。")
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
                    NavigationLink {
                        WaterLogView()
                    } label: {
                        LabeledContent("饮水记录", value: waterSummary)
                    }
                    Stepper(value: waterTarget, in: 500...5000, step: 250) {
                        LabeledContent("饮水目标", value: "\(Int(settings.waterTargetML)) mL")
                    }
                }
                Section {
                    Toggle("同步到 Apple 健康", isOn: healthToggle)
                        .disabled(!HealthKitManager.isAvailable)
                } header: {
                    Text("健康同步")
                } footer: {
                    Text(HealthKitManager.isAvailable
                         ? "开启后，每日摄入总热量将写入 Apple 健康；同时读取活动消耗计入当日预算、读取体重用于体重趋势。"
                         : "此设备不支持 HealthKit。")
                }
                Section("数据") {
                    NavigationLink {
                        DataExportView()
                    } label: {
                        Text("导出与备份")
                    }
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
        settings.globalBaseURL.isEmpty ? String(localized: "未配置") : String(localized: "已配置")
    }

    private var modelSummary: String {
        models.isEmpty ? String(localized: "0 个") : String(localized: "\(models.count) 个")
    }

    private var goalSummary: String {
        if let goal = goals.first, goal.targetCalories > 0 {
            return "\(Int(goal.targetCalories.rounded())) kcal"
        }
        return String(localized: "未设置")
    }

    private var weightSummary: String {
        guard let latest = weights.first else { return String(localized: "未记录") }
        return String(format: "%.1f kg", latest.weightKg)
    }

    private var waterSummary: String {
        let today = waters.onSameDay(as: .now).totalML
        return "\(Int(today.rounded())) mL"
    }

    private var tokenSummary: String {
        let today = tokenRecords.onSameDay(as: .now).totalTokens
        return today > 0 ? String(localized: "今日 \(today)") : String(localized: "暂无")
    }

    private var waterTarget: Binding<Double> {
        Binding(
            get: { settings.waterTargetML },
            set: { settings.waterTargetML = $0 }
        )
    }

    private var highPrecision: Binding<Bool> {
        Binding(
            get: { settings.highPrecisionMode },
            set: { settings.highPrecisionMode = $0 }
        )
    }

    private var precisionSamples: Binding<Int> {
        Binding(
            get: { settings.precisionSampleCount },
            set: { settings.precisionSampleCount = $0 }
        )
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
