import SwiftUI
import SwiftData
import Charts

struct WeightLogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @Query private var goals: [DailyGoal]

    @State private var showInput = false
    @State private var healthPoints: [WeightPoint] = []

    private var merged: [WeightPoint] {
        WeightPoint.merged(local: entries, health: healthPoints)
    }

    private var latestWeight: Double {
        merged.last?.weightKg ?? goals.first?.weightKg ?? 60
    }

    var body: some View {
        List {
            if merged.count >= 2 {
                Section("趋势") { chart }
            }
            if merged.isEmpty {
                ContentUnavailableView(
                    "还没有体重记录",
                    systemImage: "scalemass",
                    description: Text("请使用右上角「+」记录，或在「设置 → 健康」中授权读取 Apple 健康的体重数据")
                )
            } else {
                Section("历史") {
                    ForEach(merged.reversed()) { point in
                        HStack {
                            Text(point.date, format: .dateTime.year().month().day())
                            if !point.isLocal {
                                Text("健康")
                                    .font(.caption2)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.tint.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.tint)
                            }
                            Spacer()
                            Text(weightText(point.weightKg)).fontWeight(.medium)
                        }
                        .swipeActions {
                            if let entry = point.localEntry {
                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("体重记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInput = true } label: { Image(systemName: "plus") }
            }
        }
        .task {
            // 体重记录页展示完整历史，显式取全部样本。
            healthPoints = await HealthKitManager.bodyMassSamples(since: nil)
            syncGoalWeight()
        }
        .sheet(isPresented: $showInput) {
            WeightInputSheet(weight: latestWeight) { date, weight in
                add(date: date, weight: weight)
            }
        }
    }

    private var chart: some View {
        Chart(merged) { point in
            LineMark(
                x: .value("日期", point.date),
                y: .value("体重", point.weightKg)
            )
            .interpolationMethod(.monotone)
            PointMark(
                x: .value("日期", point.date),
                y: .value("体重", point.weightKg)
            )
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 200)
        .padding(.vertical, 4)
    }

    private func weightText(_ kg: Double) -> String {
        String(format: "%.1f kg", kg)
    }

    private func add(date: Date, weight: Double) {
        context.insert(WeightEntry(date: date, weightKg: weight))
        syncGoalWeight()
    }

    private func delete(_ entry: WeightEntry) {
        context.delete(entry)
        syncGoalWeight()
    }

    /// 用最新一条体重（本地或健康，取最新日期）更新目标里的体重并重算 TDEE。
    private func syncGoalWeight() {
        guard let goal = goals.first else { return }
        var latestDate = Date.distantPast
        var latestWeight: Double?
        var descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        if let local = try? context.fetch(descriptor).first, local.date > latestDate {
            latestDate = local.date
            latestWeight = local.weightKg
        }
        if let health = healthPoints.max(by: { $0.date < $1.date }), health.date > latestDate {
            latestDate = health.date
            latestWeight = health.weightKg
        }
        guard let weight = latestWeight, abs(goal.weightKg - weight) > 0.001 else { return }
        goal.weightKg = weight
        goal.recompute()
    }
}

private struct WeightInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var weight: Double
    let onSave: (Date, Double) -> Void

    init(weight: Double, onSave: @escaping (Date, Double) -> Void) {
        _weight = State(initialValue: weight)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("日期", selection: $date, displayedComponents: [.date])
                HStack {
                    Text("体重")
                    Spacer()
                    TextField("kg", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                    Text("kg").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("记录体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(date, weight)
                        dismiss()
                    }
                    .disabled(weight <= 0)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { WeightLogView() }
        .modelContainer(PreviewData.container)
}
