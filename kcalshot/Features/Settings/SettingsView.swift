import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var models: [APIModelConfig]
    @Query private var goals: [DailyGoal]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var waters: [WaterEntry]
    @Query private var tokenRecords: [TokenUsage]
    @State private var showRestartAlert = false

    // 图标磁贴配色
    private let cCoral = Color.brandCoral
    private let cGreen = Color.brandGreenDeep
    private let cOrange = Color(red: 180.0/255, green: 118.0/255, blue: 0)
    private let cWater = Color.waterBlue
    private let cGray = Color.inkSecondary

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 2, trailing: 4))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("API & 模型") {
                    NavigationLink {
                        APISettingsView()
                    } label: {
                        rowLabel("link", cCoral, "API 设置", value: globalSummary)
                    }
                    NavigationLink {
                        ModelListView()
                    } label: {
                        rowLabel("cpu", cGreen, "模型管理", value: modelSummary)
                    }
                }

                Section {
                    Toggle(isOn: highPrecision) {
                        rowTitle("sparkles", cOrange, "高精度模式")
                    }
                    .tint(.brandGreen)
                    if settings.highPrecisionMode {
                        HStack(spacing: 12) {
                            rowTitle("waveform.path.ecg", cOrange, "采样次数")
                            Spacer()
                            Text("\(settings.precisionSampleCount)").foregroundStyle(Color.inkTertiary)
                            Stepper("", value: precisionSamples, in: 3...5, step: 2).labelsHidden()
                        }
                    }
                    NavigationLink {
                        TokenUsageView()
                    } label: {
                        rowLabel("clock", cWater, "Token 用量", value: tokenSummary)
                    }
                } header: {
                    Text("识别")
                } footer: {
                    Text("开启后，每次识别会对同一张照片多次采样并取中位数，准确度更稳但 API 成本与耗时按采样次数成倍增加（识别失败会自动重试，实际请求可能更多）。")
                }

                Section {
                    Toggle(isOn: saveOriginalPhoto) {
                        rowTitle("camera.fill", cCoral, "保存原图到相册")
                    }
                    .tint(.brandGreen)
                } header: {
                    Text("照片")
                } footer: {
                    Text("仅保存新拍摄的照片；从相册选择的图片不会重复保存。")
                }

                Section("每日目标") {
                    NavigationLink {
                        GoalSettingsView()
                    } label: {
                        rowLabel("target", cGreen, "目标热量", value: goalSummary)
                    }
                    NavigationLink {
                        WeightLogView()
                    } label: {
                        rowLabel("figure.stand", cOrange, "体重记录", value: weightSummary)
                    }
                    NavigationLink {
                        WaterLogView()
                    } label: {
                        rowLabel("drop.fill", cWater, "饮水记录", value: waterSummary)
                    }
                    HStack(spacing: 12) {
                        rowTitle("drop.triangle", cWater, "饮水目标")
                        Spacer()
                        Text("\(Int(settings.waterTargetML)) mL").foregroundStyle(Color.inkTertiary)
                        Stepper("", value: waterTarget, in: 500...5000, step: 250).labelsHidden()
                    }
                }

                Section {
                    Toggle(isOn: healthToggle) {
                        rowTitle("heart.fill", cCoral, "同步到 Apple 健康")
                    }
                    .tint(.brandGreen)
                    .disabled(!HealthKitManager.isAvailable)
                } header: {
                    Text("健康同步")
                } footer: {
                    Text(HealthKitManager.isAvailable
                         ? "开启后，每日摄入总热量将写入 Apple 健康；同时读取活动消耗计入当日预算、读取体重用于体重趋势。"
                         : "此设备不支持 HealthKit。")
                }

                Section {
                    Picker(selection: languageSelection) {
                        ForEach(AppLanguagePreference.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    } label: {
                        rowTitle("globe", cGreen, "语言")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("界面")
                } footer: {
                    Text("更改语言需重启 App 后完整生效。")
                }

                Section("数据") {
                    NavigationLink {
                        DataExportView()
                    } label: {
                        rowTitle("arrow.down.doc", cOrange, "导出与备份")
                    }
                }

                Section("关于") {
                    NavigationLink {
                        PrivacyInfoView()
                    } label: {
                        rowTitle("lock.shield", cGray, "数据与隐私")
                    }
                    HStack(spacing: 12) {
                        rowTitle("info.circle", cGray, "版本")
                        Spacer()
                        Text(AppVersion.displayString(from: .main)).foregroundStyle(Color.inkTertiary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .alert("重启后生效", isPresented: $showRestartAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("语言更改将在下次启动 App 时完整生效，请手动关闭并重新打开 App。")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("偏好与数据")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            Text("设置")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 行组件

    private func iconTile(_ system: String, _ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(color.opacity(0.14))
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: system)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
    }

    private func rowTitle(_ icon: String, _ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            iconTile(icon, color)
            Text(title).foregroundStyle(Color.inkPrimary)
        }
    }

    private func rowLabel(_ icon: String, _ color: Color, _ title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 12) {
            iconTile(icon, color)
            Text(title).foregroundStyle(Color.inkPrimary)
            Spacer()
            Text(value).foregroundStyle(Color.inkTertiary)
        }
    }

    // MARK: - 绑定与摘要

    private var languageSelection: Binding<AppLanguagePreference> {
        Binding(
            get: { settings.appLanguage },
            set: { newValue in
                guard newValue != settings.appLanguage else { return }
                settings.appLanguage = newValue
                showRestartAlert = true
            }
        )
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

    private var saveOriginalPhoto: Binding<Bool> {
        Binding(
            get: { settings.saveOriginalPhoto },
            set: { settings.saveOriginalPhoto = $0 }
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
