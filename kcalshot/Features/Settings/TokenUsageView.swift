import SwiftUI
import SwiftData

/// Token 用量详情：今日/累计合计、按模型拆分、按日历史。
struct TokenUsageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TokenUsage.date, order: .reverse) private var records: [TokenUsage]

    private struct Stats {
        var today = 0
        var cumulative = 0
        var byModel: [(model: String, total: Int)] = []
        var byDay: [(day: Date, total: Int, records: [TokenUsage])] = []
    }

    /// 一次遍历算出全部汇总，避免每次渲染重复多趟 Dictionary 分组。records 已按日期倒序，分组内顺序无需再排。
    private func makeStats() -> Stats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var stats = Stats()
        var modelTotals: [String: Int] = [:]
        var dayGroups: [Date: [TokenUsage]] = [:]
        for r in records {
            stats.cumulative += r.totalTokens
            let day = cal.startOfDay(for: r.date)
            if day == today { stats.today += r.totalTokens }
            modelTotals[r.modelDisplay, default: 0] += r.totalTokens
            dayGroups[day, default: []].append(r)
        }
        stats.byModel = modelTotals.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        stats.byDay = dayGroups.keys.sorted(by: >).map { day in
            (day, dayGroups[day]!.totalTokens, dayGroups[day]!)
        }
        return stats
    }

    var body: some View {
        let stats = makeStats()
        return List {
            if records.isEmpty {
                ContentUnavailableView(
                    "暂无 Token 记录",
                    systemImage: "number",
                    description: Text("识别食物后会在此累计每次的 Token 用量（部分中转站可能不返回用量）")
                )
            } else {
                Section("合计") {
                    LabeledContent("今日", value: "\(stats.today)")
                    LabeledContent("累计", value: "\(stats.cumulative)")
                }

                Section("按模型") {
                    ForEach(stats.byModel, id: \.model) { group in
                        LabeledContent(group.model, value: "\(group.total)")
                    }
                }

                ForEach(stats.byDay, id: \.day) { group in
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
            // 部分中转站只回总量、不回输入/输出明细，这时省略「输入 0 / 输出 0」以免误导。
            Text(breakdown(record))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func breakdown(_ record: TokenUsage) -> String {
        guard record.promptTokens > 0 || record.completionTokens > 0 else { return record.modelDisplay }
        return String(localized: "\(record.modelDisplay) · 输入 \(record.promptTokens) / 输出 \(record.completionTokens)")
    }
}

#Preview {
    NavigationStack { TokenUsageView() }
        .modelContainer(PreviewData.container)
}
