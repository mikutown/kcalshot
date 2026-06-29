import SwiftUI
import SwiftData

/// Token 用量详情：今日/累计合计、按模型拆分、按日历史。
struct TokenUsageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TokenUsage.date, order: .reverse) private var records: [TokenUsage]

    private var todayTotal: Int { records.onSameDay(as: .now).totalTokens }
    private var cumulativeTotal: Int { records.totalTokens }

    private var byDay: [(day: Date, total: Int, records: [TokenUsage])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: records) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            let dayRecords = groups[day]!.sorted { $0.date > $1.date }
            return (day, dayRecords.totalTokens, dayRecords)
        }
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "暂无 Token 记录",
                    systemImage: "number",
                    description: Text("识别食物后会在此累计每次的 Token 用量（部分中转站可能不返回用量）")
                )
            } else {
                Section("合计") {
                    LabeledContent("今日", value: "\(todayTotal)")
                    LabeledContent("累计", value: "\(cumulativeTotal)")
                }

                Section("按模型") {
                    ForEach(records.groupedByModel(), id: \.model) { group in
                        LabeledContent(group.model, value: "\(group.total)")
                    }
                }

                ForEach(byDay, id: \.day) { group in
                    Section {
                        ForEach(group.records) { record in
                            row(record)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        context.delete(record)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(group.day, format: .dateTime.year().month().day())
                            Spacer()
                            Text("\(group.total)")
                        }
                    }
                }
            }
        }
        .navigationTitle("Token 用量")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ record: TokenUsage) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(record.date, format: .dateTime.hour().minute())
                    .foregroundStyle(.secondary)
                Text(record.kind.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
                Spacer()
                Text("\(record.totalTokens)").fontWeight(.medium)
            }
            Text("\(record.modelDisplay) · 输入 \(record.promptTokens) / 输出 \(record.completionTokens)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { TokenUsageView() }
        .modelContainer(PreviewData.container)
}
