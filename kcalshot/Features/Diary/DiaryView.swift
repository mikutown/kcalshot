import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]

    var body: some View {
        NavigationStack {
            Group {
                if allEntries.isEmpty {
                    ContentUnavailableView(
                        "暂无历史记录",
                        systemImage: "calendar",
                        description: Text("保存的三餐会按日期出现在这里")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("记录")
        }
    }

    private var list: some View {
        List {
            ForEach(allEntries.groupedByDay(), id: \.day) { group in
                Section {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            MealEditView(entry: entry, isNew: false)
                        } label: {
                            MealEntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in delete(group.entries, offsets) }
                } header: {
                    HStack {
                        Text(group.day, format: .dateTime.month().day().weekday())
                        Spacer()
                        Text("\(Int(NutritionTotals(group.entries).calories.rounded())) kcal")
                    }
                }
            }
        }
    }

    private func delete(_ entries: [MealEntry], _ offsets: IndexSet) {
        for index in offsets { context.delete(entries[index]) }
    }
}

#Preview {
    DiaryView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
