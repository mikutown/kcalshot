import SwiftUI
import SwiftData

/// 日历相关的日期计算（周日为一周起始，与表头「日 一 二…」一致）。
enum CalendarMath {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }()

    static func monthStart(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    static func currentMonthStart() -> Date { monthStart(Date()) }

    /// 某月的格子：前导空位（nil）补齐到周起始，后接当月每一天。
    static func cells(of monthStart: Date) -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        return result
    }
}

/// 当天摄入相对目标的达成状态。
enum DayStatus {
    case none, under, onTarget, over

    init(intake: Double, target: Double) {
        guard intake > 0, target > 0 else { self = .none; return }
        let ratio = intake / target
        if ratio < 0.9 { self = .under }
        else if ratio <= 1.1 { self = .onTarget }
        else { self = .over }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .under: return .yellow
        case .onTarget: return .green
        case .over: return .red
        }
    }
}

struct DiaryView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @Query private var goals: [DailyGoal]

    @State private var selectedMonth = CalendarMath.currentMonthStart()
    @State private var selectedDay: Date?

    private var target: Double { goals.first?.targetCalories ?? 0 }

    private var intakeByDay: [Date: Double] {
        Dictionary(grouping: allEntries) { CalendarMath.calendar.startOfDay(for: $0.date) }
            .mapValues { NutritionTotals($0).calories }
    }

    private var months: [Date] {
        let current = CalendarMath.currentMonthStart()
        let earliest = allEntries.last.map { CalendarMath.monthStart($0.date) } ?? current
        let start = CalendarMath.calendar.date(byAdding: .month, value: -12, to: min(earliest, current))!
        let end = CalendarMath.calendar.date(byAdding: .month, value: 12, to: current)!
        var result: [Date] = []
        var month = start
        while month <= end {
            result.append(month)
            month = CalendarMath.calendar.date(byAdding: .month, value: 1, to: month)!
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(Self.monthTitle.string(from: selectedMonth))
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                weekdayHeader

                TabView(selection: $selectedMonth) {
                    ForEach(months, id: \.self) { month in
                        monthGrid(month).tag(month)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 380)

                legend
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle("记录")
            .navigationDestination(item: $selectedDay) { day in
                DayDetailView(date: day)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private func monthGrid(_ month: Date) -> some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(CalendarMath.cells(of: month).enumerated()), id: \.offset) { _, date in
                if let date {
                    DayCell(
                        date: date,
                        intake: intakeByDay[CalendarMath.calendar.startOfDay(for: date)] ?? 0,
                        target: target
                    ) { selectedDay = date }
                } else {
                    Color.clear.frame(height: 1)
                }
            }
        }
        .padding(.horizontal)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(.over, "超出")
            legendItem(.onTarget, "适中")
            legendItem(.under, "不足")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ status: DayStatus, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(status.color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    private static let monthTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 MM 月"
        return f
    }()
}

private struct DayCell: View {
    let date: Date
    let intake: Double
    let target: Double
    let onTap: () -> Void

    private var status: DayStatus { DayStatus(intake: intake, target: target) }
    private var fill: Double { target > 0 ? min(intake / target, 1) : 0 }
    private var dayNumber: Int { CalendarMath.calendar.component(.day, from: date) }
    private var isToday: Bool { CalendarMath.calendar.isDateInToday(date) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 3)
                    if status != .none {
                        Circle()
                            .trim(from: 0, to: fill)
                            .stroke(status.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Text("\(dayNumber)")
                        .font(.callout)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? Color.accentColor : .primary)
                }
                .frame(width: 40, height: 40)

                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DiaryView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
