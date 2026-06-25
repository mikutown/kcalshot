import SwiftUI
import SwiftData
import PhotosUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @Query private var goals: [DailyGoal]
    @State private var showCapture = false
    @State private var captureMode: CaptureView.InputMode = .photo
    @State private var showGoalSheet = false
    @State private var showGoalPrompt = false
    @State private var didCheckGoal = false
    @State private var showSourceDialog = false
    @State private var pickedImage: UIImage?

    private var todayEntries: [MealEntry] { allEntries.onSameDay(as: .now) }

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
                if todayEntries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .navigationTitle("今天")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(Color.accentColor)
                        .contentShape(Rectangle())
                        .onTapGesture { showSourceDialog = true }
                        .onLongPressGesture(minimumDuration: 0.4) { openCapture(.text) }
                        .accessibilityLabel("拍照识别")
                        .accessibilityHint("长按可改用文字记录")
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
        .alert("设置每日目标", isPresented: $showGoalPrompt) {
            Button("去设置") { showGoalSheet = true }
            Button("暂不", role: .cancel) {}
        } message: {
            Text("先设置你的每日热量与营养目标，今天页就能看到每天的摄入进度。")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("今天还没有记录", systemImage: "fork.knife")
        } description: {
            Text("拍一张照片，或用文字记录你的第一餐")
        } actions: {
            Button { showSourceDialog = true } label: {
                Label("拍照识别", systemImage: "camera.fill")
            }
            .buttonStyle(.borderedProminent)
            Button { openCapture(.text) } label: {
                Label("文字记录", systemImage: "text.cursor")
            }
            .buttonStyle(.bordered)
        }
    }

    private var entryList: some View {
        List {
            Section {
                DailySummaryCard(entries: todayEntries, goal: goals.first)
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
