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
        case .under: return .brandOrange
        case .onTarget: return .brandGreen
        case .over: return .brandCoral
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
            ScrollView {
                VStack(spacing: 16) {
                    header

                    VStack(spacing: 14) {
                        monthNav
                        weekdayHeader
                        monthGrid(selectedMonth)
                    }
                    .cardStyle(padding: 16)

                    legend
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedDay) { day in
                DayDetailView(date: day)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("月度摄入达标一览")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            Text("记录")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var monthNav: some View {
        HStack {
            navButton("chevron.left") { shiftMonth(-1) }
            Spacer()
            Text(Self.monthTitle.string(from: selectedMonth))
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            navButton("chevron.right") { shiftMonth(1) }
        }
    }

    private func navButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.05), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = CalendarMath.calendar.date(byAdding: .month, value: delta, to: selectedMonth),
              let first = months.first, let last = months.last,
              next >= first, next <= last else { return }
        withAnimation(.snappy) { selectedMonth = next }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(LocalizedStringKey(day))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthGrid(_ month: Date) -> some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(CalendarMath.cells(of: month).enumerated()), id: \.offset) { _, date in
                if let date {
                    DayCell(
                        date: date,
                        intake: intakeByDay[CalendarMath.calendar.startOfDay(for: date)] ?? 0,
                        target: target
                    ) { selectedDay = date }
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(.onTarget, "适中")
            legendItem(.under, "不足")
            legendItem(.over, "超出")
            legendItem(.none, "未记录")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.inkSecondary)
    }

    private func legendItem(_ status: DayStatus, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status == .none ? Color.hairline : status.color)
                .frame(width: 9, height: 9)
            Text(label)
        }
    }

    private static let monthTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMMM")
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
            ZStack {
                Circle().stroke(Color.hairline, lineWidth: 3)
                if status != .none {
                    Circle()
                        .trim(from: 0, to: fill)
                        .stroke(status.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                if isToday {
                    Circle().fill(Color.brandGreen).frame(width: 28, height: 28)
                }
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(dayNumberColor)
            }
            .frame(width: 40, height: 40)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var dayNumberColor: Color {
        if isToday { return .white }
        return status == .none ? Color.inkTertiary : Color.inkPrimary
    }
}

#Preview {
    DiaryView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
