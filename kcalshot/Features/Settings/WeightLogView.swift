import SwiftUI
import SwiftData
import Charts

struct WeightLogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @Query private var goals: [DailyGoal]

    @State private var showInput = false

    private var latestWeight: Double {
        entries.last?.weightKg ?? goals.first?.weightKg ?? 60
    }

    var body: some View {
        List {
            if entries.count >= 2 {
                Section("趋势") { chart }
            }
            if entries.isEmpty {
                ContentUnavailableView(
                    "还没有体重记录",
                    systemImage: "scalemass",
                    description: Text("用右上角「+」记录一次体重")
                )
            } else {
                Section("历史") {
                    ForEach(entries.reversed()) { entry in
                        HStack {
                            Text(entry.date, format: .dateTime.year().month().day())
                            Spacer()
                            Text(weightText(entry.weightKg)).fontWeight(.medium)
                        }
                    }
                    .onDelete(perform: delete)
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
        .sheet(isPresented: $showInput) {
            WeightInputSheet(weight: latestWeight) { date, weight in
                add(date: date, weight: weight)
            }
        }
    }

    private var chart: some View {
        Chart(entries) { entry in
            LineMark(
                x: .value("日期", entry.date),
                y: .value("体重", entry.weightKg)
            )
            .interpolationMethod(.monotone)
            PointMark(
                x: .value("日期", entry.date),
                y: .value("体重", entry.weightKg)
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

    private func delete(_ offsets: IndexSet) {
        let reversed = entries.reversed().map { $0 }
        for index in offsets { context.delete(reversed[index]) }
        syncGoalWeight()
    }

    /// 用最新一条体重更新目标里的体重并重算 TDEE。
    private func syncGoalWeight() {
        var descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let latest = try? context.fetch(descriptor).first, let goal = goals.first else { return }
        goal.weightKg = latest.weightKg
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
