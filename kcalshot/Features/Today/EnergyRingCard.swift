import SwiftUI

/// 「今天」主屏的能量卡：绿→橙渐变能量环（剩余额度居中）+ 已摄入/目标/运动
/// 三行统计 + 撞色宏量小卡。对应 opendesign 稿 today.html 的 hero 卡。
struct EnergyRingCard: View {
    let entries: [MealEntry]
    var goal: DailyGoal?
    /// 当天活动消耗（kcal），计入可吃预算。
    var exercise: Double = 0

    private var totals: NutritionTotals { NutritionTotals(entries) }
    private var hasGoal: Bool { (goal?.targetCalories ?? 0) > 0 }
    private var target: Double { goal?.targetCalories ?? 0 }
    private var budget: Double { target + exercise }
    private var remaining: Double { budget - totals.calories }
    private var isOver: Bool { remaining < 0 }
    private var progress: Double { budget > 0 ? min(totals.calories / budget, 1) : 0 }

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 18) {
                ring
                stats
            }
            macros
        }
        .cardStyle()
    }

    // MARK: 能量环

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.hairline, lineWidth: 14)
            Circle()
                .trim(from: 0, to: hasGoal ? progress : 0)
                .stroke(
                    AngularGradient(
                        // 未超标：绿（浅→深），已超标：珊红。与图例/中心文案一致，不出现无解释的黄色。
                        gradient: Gradient(colors: isOver ? [.brandCoral, .brandCoral] : [.brandGreen, .brandGreenDeep]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(hasGoal ? (isOver ? "已超出" : "还可摄入") : "今日摄入")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.inkTertiary)
                Text("\(Int((hasGoal ? abs(remaining) : totals.calories).rounded()))")
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isOver ? Color.brandCoral : Color.inkPrimary)
                Text("kcal")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(width: 132, height: 132)
    }

    // MARK: 右侧统计

    private var stats: some View {
        VStack(spacing: 12) {
            statRow(color: .brandGreen, label: "已摄入", value: totals.calories)
            statRow(color: .inkTertiary, label: "目标", value: target, muted: !hasGoal)
            statRow(color: .brandCoral, label: "运动消耗", value: exercise)
        }
        .frame(maxWidth: .infinity)
    }

    private func statRow(color: Color, label: LocalizedStringKey, value: Double, muted: Bool = false) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 4)
            Group {
                if muted {
                    Text("未设置").foregroundStyle(Color.inkTertiary)
                } else {
                    Text("\(Int(value.rounded()))").monospacedDigit()
                    + Text(" kcal").font(.caption2).foregroundStyle(Color.inkTertiary)
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.inkPrimary)
        }
    }

    // MARK: 撞色宏量小卡

    private var macros: some View {
        HStack(spacing: 10) {
            macroChip("蛋白质", value: totals.protein, target: goal?.protein,
                      tint: .macroProtein, labelColor: .brandGreenDeep)
            macroChip("碳水", value: totals.carbs, target: goal?.carbs,
                      tint: .macroCarbs, labelColor: Color(red: 180.0/255, green: 118.0/255, blue: 0))
            macroChip("脂肪", value: totals.fat, target: goal?.fat,
                      tint: .macroFat, labelColor: Color(red: 214.0/255, green: 74.0/255, blue: 42.0/255))
        }
    }

    private func macroChip(_ name: String, value: Double, target: Double?, tint: Color, labelColor: Color) -> some View {
        let hasTarget = (target ?? 0) > 0
        let frac = hasTarget ? min(value / target!, 1) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Group {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 12, weight: .heavy))
                        .monospacedDigit()
                    + Text(hasTarget ? "/\(Int(target!.rounded()))g" : "g")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.06))
                    Capsule().fill(tint).frame(width: max(6, geo.size.width * frac))
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    EnergyRingCard(entries: [], goal: nil)
        .padding()
        .background(Color.appBackground)
}
