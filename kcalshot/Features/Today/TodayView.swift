import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @State private var showCapture = false

    private var todayEntries: [MealEntry] { allEntries.onSameDay(as: .now) }

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
                    Button { showCapture = true } label: { Image(systemName: "camera.fill") }
                }
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("今天还没有记录", systemImage: "fork.knife")
        } description: {
            Text("拍一张照片，开始记录你的第一餐")
        } actions: {
            Button { showCapture = true } label: {
                Label("拍照识别", systemImage: "camera.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var entryList: some View {
        List {
            Section {
                DailySummaryCard(entries: todayEntries)
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
