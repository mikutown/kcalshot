import SwiftUI
import SwiftData
import PhotosUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @Query private var goals: [DailyGoal]
    @Query(sort: \WaterEntry.date, order: .reverse) private var allWater: [WaterEntry]
    @State private var showCapture = false
    @State private var captureMode: CaptureView.InputMode = .photo
    @State private var showGoalSheet = false
    @State private var showGoalPrompt = false
    @State private var didCheckGoal = false
    @State private var showSourceDialog = false
    @State private var showWaterLog = false
    @State private var showQuickAdd = false
    @State private var pickedImage: UIImage?
    @State private var exercise: Double = 0

    private var todayEntries: [MealEntry] { allEntries.onSameDay(as: .now) }
    private var todayWater: [WaterEntry] { allWater.onSameDay(as: .now) }
    private var todayWaterTotal: Double { todayWater.totalML }

    private var hasGoal: Bool { (goals.first?.targetCalories ?? 0) > 0 }

    /// 当开关或当日总热量变化时触发健康同步。
    private var healthSyncKey: String {
        "\(settings.healthSyncEnabled)-\(Int(NutritionTotals(todayEntries).calories.rounded()))"
    }

    private func openCapture(_ mode: CaptureView.InputMode) {
        captureMode = mode
        showCapture = true
    }

    /// 拿到照片后进入识别页（图片已落在矩形预览区）。
    private func presentPhotoCapture(_ image: UIImage) {
        pickedImage = image
        captureMode = .photo
        showCapture = true
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
            .navigationDestination(isPresented: $showWaterLog) {
                WaterLogView()
            }
            .navigationTitle("今天")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showQuickAdd = true
                    } label: {
                        Image(systemName: "bolt.fill")
                    }
                    .accessibilityLabel("快速添加")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(Color.accentColor)
                        .contentShape(Rectangle())
                        .onTapGesture { showSourceDialog = true }
                        .onLongPressGesture(minimumDuration: 0.4) { openCapture(.text) }
                        .accessibilityLabel("拍照识别")
                        .accessibilityHint("长按可切换为文字记录")
                }
            }
        }
        .photoSourcePicker(isPresented: $showSourceDialog) { image in
            presentPhotoCapture(image)
        }
        .onChange(of: showCapture) { _, isShown in
            if !isShown { pickedImage = nil }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView(mode: captureMode, initialImage: pickedImage)
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView()
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("今天还没有记录", systemImage: "fork.knife")
        } description: {
            Text("请拍摄照片，或通过文字记录第一餐")
        } actions: {
            Button { showSourceDialog = true } label: {
                Label("拍照识别", systemImage: "camera.fill")
            }
            .buttonStyle(.borderedProminent)
            Button { openCapture(.text) } label: {
                Label("文字记录", systemImage: "text.cursor")
            }
            .buttonStyle(.bordered)
            Button { addWater(250) } label: {
                Label("记录一杯水", systemImage: "drop.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    private func addWater(_ ml: Double) {
        context.insert(WaterEntry(amountML: ml))
    }

    private var entryList: some View {
        List {
            Section {
                DailySummaryCard(entries: todayEntries, goal: goals.first, exercise: exercise)
            }
            Section {
                WaterCard(
                    totalML: todayWaterTotal,
                    targetML: settings.waterTargetML,
                    onAdd: addWater,
                    onOpenLog: { showWaterLog = true }
                )
            }
            ForEach(todayEntries.groupedByMeal(), id: \.meal) { group in
                Section(group.meal.displayName) {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            MealEditView(entry: entry, isNew: false)
                        } label: {
                            MealEntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in delete(group.entries, offsets) }
                }
            }
        }
    }

    private func delete(_ entries: [MealEntry], _ offsets: IndexSet) {
        for index in offsets { context.delete(entries[index]) }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
