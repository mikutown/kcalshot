import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @Query private var goals: [DailyGoal]
    @State private var showCapture = false
    @State private var captureMode: CaptureView.InputMode = .photo

    private var todayEntries: [MealEntry] { allEntries.onSameDay(as: .now) }

    private func openCapture(_ mode: CaptureView.InputMode) {
        captureMode = mode
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
                        .onTapGesture { openCapture(.photo) }
                        .onLongPressGesture(minimumDuration: 0.4) { openCapture(.text) }
                        .accessibilityLabel("拍照识别")
                        .accessibilityHint("长按可改用文字记录")
                }
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView(mode: captureMode)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("今天还没有记录", systemImage: "fork.knife")
        } description: {
            Text("拍一张照片，或用文字记录你的第一餐")
        } actions: {
            Button { openCapture(.photo) } label: {
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
