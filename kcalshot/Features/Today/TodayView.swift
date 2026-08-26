import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(AddCoordinator.self) private var add
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @Query private var goals: [DailyGoal]
    @Query(sort: \WaterEntry.date, order: .reverse) private var allWater: [WaterEntry]
    @State private var showGoalSheet = false
    @State private var showGoalPrompt = false
    @State private var didCheckGoal = false
    @State private var showWaterLog = false
    @State private var exercise: Double = 0

    private var todayEntries: [MealEntry] { allEntries.onSameDay(as: .now) }
    private var todayWater: [WaterEntry] { allWater.onSameDay(as: .now) }
    private var todayWaterTotal: Double { todayWater.totalML }

    private var hasGoal: Bool { (goals.first?.targetCalories ?? 0) > 0 }

    /// 当开关或当日总热量变化时触发健康同步。
    private var healthSyncKey: String {
        "\(settings.healthSyncEnabled)-\(Int(NutritionTotals(todayEntries).calories.rounded()))"
    }

    var body: some View {
        NavigationStack {
            Group {
                if todayEntries.isEmpty && todayWaterTotal == 0 {
                    emptyState
                } else {
                    entryList
                }
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showWaterLog) {
                WaterLogView()
            }
        }
        .sheet(isPresented: $showGoalSheet) {
            NavigationStack { GoalSettingsView(showsDone: true) }
        }
        .task {
            // 首次（尚未设置目标）引导用户去设置，每次启动最多提醒一次。
            guard !didCheckGoal else { return }
            didCheckGoal = true
            if !hasGoal { showGoalPrompt = true }
        }
        .task(id: healthSyncKey) {
            guard settings.healthSyncEnabled else { return }
            await HealthKitManager.syncDailyTotal(
                NutritionTotals(todayEntries).calories, for: .now
            )
        }
        .task(id: settings.healthSyncEnabled) {
            exercise = await HealthKitManager.activeEnergy(for: .now)
        }
        .task(id: "\(settings.healthSyncEnabled)-water-\(Int(todayWaterTotal.rounded()))") {
            guard settings.healthSyncEnabled else { return }
            await HealthKitManager.syncDailyWater(todayWaterTotal, for: .now)
        }
        .alert("设置每日目标", isPresented: $showGoalPrompt) {
            Button("前往设置") { showGoalSheet = true }
            Button("暂不设置", role: .cancel) {}
        } message: {
            Text("请先设置每日热量与营养目标，「今天」页即可查看每日摄入进度。")
        }
    }

    // MARK: - 顶部问候

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return String(localized: "早上好")
        case 11..<14: return String(localized: "中午好")
        case 14..<18: return String(localized: "下午好")
        default: return String(localized: "晚上好")
        }
    }

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: .now)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            Text(dateTitle)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 列表

    private var entryList: some View {
        List {
            clearSection { header }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))

            clearSection {
                EnergyRingCard(entries: todayEntries, goal: goals.first, exercise: exercise)
            }

            clearSection {
                WaterCard(
                    totalML: todayWaterTotal,
                    targetML: settings.waterTargetML,
                    onAdd: addWater,
                    onOpenLog: { showWaterLog = true }
                )
            }

            ForEach(MealType.orderedCases) { meal in
                let mealEntries = todayEntries
                    .filter { $0.mealType == meal }
                    .sorted { $0.date < $1.date }
                if mealEntries.isEmpty {
                    Section {
                        emptyMealRow(meal)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } header: {
                        mealHeader(meal: meal, entries: mealEntries)
                    }
                } else {
                    Section {
                        ForEach(mealEntries) { entry in
                            NavigationLink {
                                MealEditView(entry: entry, isNew: false)
                            } label: {
                                MealEntryRow(entry: entry)
                            }
                        }
                        .onDelete { offsets in delete(mealEntries, offsets) }
                    } header: {
                        mealHeader(meal: meal, entries: mealEntries)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    /// 透明背景、无分隔线的卡片承载区（能量卡/水卡自带圆角与阴影）。
    private func clearSection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Section { content() }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func mealHeader(meal: MealType, entries: [MealEntry]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(meal.displayName)
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            if entries.isEmpty {
                Text("— kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.inkTertiary)
            } else {
                Text("\(Int(NutritionTotals(entries).calories.rounded())) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandGreenDeep)
            }
        }
        .textCase(nil)
        .padding(.top, 6)
    }

    private func emptyMealRow(_ meal: MealType) -> some View {
        Button {
            add.openMenu(meal: meal)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("拍照或文字添加\(meal.displayName)")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.inkTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.inkTertiary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        ContentUnavailableView {
            Label("今天还没有记录", systemImage: "fork.knife")
        } description: {
            Text("请拍摄照片，或通过文字记录第一餐")
        } actions: {
            Button { add.startPhoto() } label: {
                Label("拍照识别", systemImage: "camera.fill")
            }
            .buttonStyle(.borderedProminent)
            Button { add.startText() } label: {
                Label("文字记录", systemImage: "text.cursor")
            }
            .buttonStyle(.bordered)
            Button { addWater(250) } label: {
                Label("记录一杯水", systemImage: "drop.fill")
            }
            .buttonStyle(.bordered)
        }
        .tint(.brandGreen)
    }

    // MARK: - 操作

    private func addWater(_ ml: Double) {
        context.insert(WaterEntry(amountML: ml))
    }

    private func delete(_ entries: [MealEntry], _ offsets: IndexSet) {
        for index in offsets { context.delete(entries[index]) }
        // 立即落库，促使 @Query 重新发布，能量环/宏量随即刷新。
        try? context.save()
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
