import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @Query private var goals: [DailyGoal]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]

    @State private var range: Range = .week
    @State private var healthWeights: [WeightPoint] = []

    private var mergedWeights: [WeightPoint] {
        WeightPoint.merged(local: weights, health: healthWeights)
    }

    private enum Range: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
        var title: String { self == .week ? "近 7 天" : "近 30 天" }
    }

    private struct DayIntake: Identifiable {
        let date: Date
        let intake: Double
        var id: Date { date }
    }

    private var target: Double { goals.first?.targetCalories ?? 0 }

    private var intakeByDay: [Date: Double] {
        Dictionary(grouping: allEntries) { CalendarMath.calendar.startOfDay(for: $0.date) }
            .mapValues { NutritionTotals($0).calories }
    }

    /// 区间内每一天（含无记录日，摄入为 0），最早在前。
    private var series: [DayIntake] {
        let cal = CalendarMath.calendar
        let today = cal.startOfDay(for: Date())
        return (0..<range.days).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayIntake(date: date, intake: intakeByDay[date] ?? 0)
        }
    }

    private var recordedIntakes: [Double] { series.map(\.intake).filter { $0 > 0 } }

    private var averageIntake: Double {
        recordedIntakes.isEmpty ? 0 : recordedIntakes.reduce(0, +) / Double(recordedIntakes.count)
    }

    private var onTargetDays: Int {
        series.filter { DayStatus(intake: $0.intake, target: target) == .onTarget }.count
    }

    private var recordedDays: Int { recordedIntakes.count }

    /// 从今天（或最近有记录的一天）往回数，连续达标的天数。
    private var streak: Int {
        let cal = CalendarMath.calendar
        var day = cal.startOfDay(for: Date())
        // 今天还没记录时，从昨天开始数，不打断连胜。
        if DayStatus(intake: intakeByDay[day] ?? 0, target: target) == .none {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while DayStatus(intake: intakeByDay[day] ?? 0, target: target) == .onTarget {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var body: some View {
        NavigationStack {
            Group {
                if allEntries.isEmpty {
                    ContentUnavailableView(
                        "还没有可统计的数据",
                        systemImage: "chart.bar",
                        description: Text("记录数餐后，此处将显示摄入趋势与达标情况")
                    )
                } else {
                    content
                }
            }
            .navigationTitle("统计")
            .task {
                healthWeights = await HealthKitManager.bodyMassSamples()
            }
        }
    }

    private var content: some View {
        List {
            Section {
                Picker("区间", selection: $range) {
                    ForEach(Range.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                statsRow
            }

            Section("摄入趋势") {
                intakeChart
            }

            if mergedWeights.count >= 2 {
                Section("体重趋势") {
                    weightChart
                }
            }

            if target <= 0 {
                Section {
                    Text("设置每日目标后，方可统计达标天数与连续达标。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile("平均摄入", "\(Int(averageIntake.rounded()))", "kcal")
            statTile("达标天数", "\(onTargetDays)", "/ \(recordedDays) 天")
            statTile("连续达标", "\(streak)", "天")
        }
    }

    private func statTile(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.bold))
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var intakeChart: some View {
        Chart {
            if target > 0 {
                RuleMark(y: .value("目标", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标 \(Int(target.rounded()))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
            }
            ForEach(series) { day in
                BarMark(
                    x: .value("日期", day.date, unit: .day),
                    y: .value("摄入", day.intake)
                )
                .foregroundStyle(barColor(for: day))
            }
        }
        .frame(height: 220)
        .padding(.vertical, 4)
    }

    private func barColor(for day: DayIntake) -> Color {
        let status = DayStatus(intake: day.intake, target: target)
        return status == .none ? Color(.systemGray4) : status.color
    }

    private var weightChart: some View {
        Chart(mergedWeights) { point in
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
        .frame(height: 160)
        .padding(.vertical, 4)
    }
}

#Preview {
    InsightsView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
