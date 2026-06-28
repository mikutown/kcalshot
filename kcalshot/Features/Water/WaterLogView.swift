import SwiftUI
import SwiftData

/// 饮水历史与编辑：按日分组展示，可加水/删除。
struct WaterLogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WaterEntry.date, order: .reverse) private var entries: [WaterEntry]

    @State private var showCustom = false

    private var byDay: [(day: Date, total: Double, entries: [WaterEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            let dayEntries = groups[day]!.sorted { $0.date > $1.date }
            return (day, dayEntries.totalML, dayEntries)
        }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "还没有饮水记录",
                    systemImage: "drop",
                    description: Text("请使用右上角「+」记录饮水")
                )
            } else {
                ForEach(byDay, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            HStack {
                                Text(entry.date, format: .dateTime.hour().minute())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(entry.amountML.rounded())) mL").fontWeight(.medium)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    context.delete(entry)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.day, format: .dateTime.year().month().day())
                            Spacer()
                            Text("\(Int(group.total.rounded())) mL")
                        }
                    }
                }
            }
        }
        .navigationTitle("饮水记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCustom = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCustom) {
            WaterAmountSheet { context.insert(WaterEntry(amountML: $0)) }
        }
    }
}

#Preview {
    NavigationStack { WaterLogView() }
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
