import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @Query private var goals: [DailyGoal]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]

    @State private var range: Range = .week
    @State private var weightRange: WeightRange = .month
    @State private var healthWeights: [WeightPoint] = []

    private var mergedWeights: [WeightPoint] {
        WeightPoint.merged(local: weights, health: healthWeights)
    }

    private enum Range: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
        var title: String { self == .week ? String(localized: "近 7 天") : String(localized: "近 30 天") }
    }

    private enum WeightRange: String, CaseIterable, Identifiable {
        case month, quarter, year
        var id: String { rawValue }
        var days: Int { self == .month ? 30 : (self == .quarter ? 90 : 365) }
        var title: String { self == .month ? "30天" : (self == .quarter ? "3月" : "1年") }
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

    /// 体重区间内的点。
    private var rangedWeights: [WeightPoint] {
        let cal = CalendarMath.calendar
        guard let cutoff = cal.date(byAdding: .day, value: -weightRange.days, to: Date()) else { return mergedWeights }
        return mergedWeights.filter { $0.date >= cutoff }
    }

    private var weightDelta: Double? {
        guard let first = rangedWeights.first?.weightKg, let last = rangedWeights.last?.weightKg else { return nil }
        return last - first
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
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                healthWeights = await HealthKitManager.bodyMassSamples()
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                pillSegment(Range.allCases, title: { $0.title }, selection: $range, fill: true)

                statTiles

                if target <= 0 {
                    Text("设置每日目标后，方可统计达标天数与连续达标。")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                intakeSection

                if mergedWeights.count >= 2 {
                    weightSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
    }

    // MARK: - 顶部

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("看看你的趋势")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            Text("统计")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - 数据卡

    private var statTiles: some View {
        HStack(spacing: 10) {
            statTile("平均摄入", "\(Int(averageIntake.rounded()))", "kcal",
                     tint: .brandGreen, labelColor: .brandGreenDeep)
            statTile("达标天数", "\(onTargetDays)", "/ \(recordedDays) 天",
                     tint: .brandOrange, labelColor: Color(red: 180.0/255, green: 118.0/255, blue: 0))
            statTile("连续达标", "\(streak)", "天",
                     tint: .brandCoral, labelColor: Color(red: 214.0/255, green: 74.0/255, blue: 42.0/255))
        }
    }

    private func statTile(_ title: String, _ value: String, _ unit: String, tint: Color, labelColor: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(labelColor)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 26, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 摄入趋势

    private var intakeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("摄入趋势", trailing: target > 0 ? "目标 \(Int(target.rounded())) kcal" : nil)
            VStack(spacing: 12) {
                intakeChart
                intakeLegend
            }
            .cardStyle()
        }
    }

    private var intakeChart: some View {
        Chart {
            if target > 0 {
                RuleMark(y: .value("目标", target))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    .foregroundStyle(Color.inkTertiary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标 \(Int(target.rounded()))")
                            .font(.caption2).foregroundStyle(Color.inkTertiary)
                    }
            }
            ForEach(series) { day in
                BarMark(
                    x: .value("日期", day.date, unit: .day),
                    y: .value("摄入", day.intake)
                )
                .foregroundStyle(barColor(for: day))
                .cornerRadius(6)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: range == .week ? 7 : 6)) {
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    .font(.caption2)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .chartYAxis {
            AxisMarks { AxisValueLabel().font(.caption2).foregroundStyle(Color.inkTertiary) }
        }
        .frame(height: 210)
    }

    private func barColor(for day: DayIntake) -> Color {
        switch DayStatus(intake: day.intake, target: target) {
        case .onTarget: return .brandGreen
        case .over: return .brandCoral
        case .under: return .brandOrange
        case .none: return Color.hairline
        }
    }

    private var intakeLegend: some View {
        HStack(spacing: 16) {
            legendItem(.brandGreen, "达标")
            legendItem(.brandOrange, "偏低")
            legendItem(.brandCoral, "超标")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(Color.inkSecondary)
        }
    }

    // MARK: - 体重趋势

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("体重趋势")
                    .font(.headline)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                pillSegment(WeightRange.allCases, title: { $0.title }, selection: $weightRange, fill: false, size: 12)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 8) {
                weightHeadline
                if rangedWeights.count >= 2 {
                    weightChart
                } else {
                    Text("该区间体重数据不足")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTertiary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .cardStyle()
        }
    }

    private var weightHeadline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let now = rangedWeights.last?.weightKg {
                (Text("\(now, specifier: "%.1f") ").font(.system(size: 26, weight: .heavy)).monospacedDigit()
                 + Text("kg").font(.subheadline.weight(.bold)).foregroundStyle(Color.inkTertiary))
                    .foregroundStyle(Color.inkPrimary)
            }
            if let delta = weightDelta, abs(delta) >= 0.05 {
                let down = delta < 0
                Text("\(down ? "↓" : "↑") \(abs(delta), specifier: "%.1f") kg")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(down ? Color.brandGreenDeep : Color.brandCoral)
            }
        }
    }

    private var weightChart: some View {
        Chart(rangedWeights) { point in
            AreaMark(
                x: .value("日期", point.date),
                y: .value("体重", point.weightKg)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.brandGreen.opacity(0.22), Color.brandGreen.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            LineMark(
                x: .value("日期", point.date),
                y: .value("体重", point.weightKg)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.brandGreen)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) {
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    .font(.caption2)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .chartYAxis {
            AxisMarks { AxisValueLabel().font(.caption2).foregroundStyle(Color.inkTertiary) }
        }
        .frame(height: 160)
    }

    // MARK: - 复用组件

    private func sectionHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline).foregroundStyle(Color.inkPrimary)
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline.weight(.semibold)).foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func pillSegment<T: Hashable>(
        _ options: [T],
        title: @escaping (T) -> String,
        selection: Binding<T>,
        fill: Bool,
        size: CGFloat = 14
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isOn = selection.wrappedValue == option
                Text(title(option))
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(isOn ? .white : Color.inkSecondary)
                    .frame(maxWidth: fill ? .infinity : nil)
                    .padding(.vertical, 8)
                    .padding(.horizontal, fill ? 0 : 12)
                    .background {
                        if isOn {
                            Capsule().fill(Color.brandGreen)
                                .shadow(color: Color.brandGreen.opacity(0.32), radius: 5, y: 2)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.snappy) { selection.wrappedValue = option } }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.05), in: Capsule())
    }
}

#Preview {
    InsightsView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
