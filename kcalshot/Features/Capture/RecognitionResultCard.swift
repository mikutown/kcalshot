import SwiftUI

struct RecognitionResultCard: View {
    @Binding var result: RecognitionResult

    private var modelName: String {
        result.modelUsed.isEmpty ? String(localized: "未知") : result.modelUsed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if result.needsReview {
                reviewBanner
            }
            summaryCard
            itemsCard
            infoLines
            metaLine
        }
    }

    // MARK: - 核对提示

    private var reviewBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("建议核对份量 / 识别结果")
                .font(.subheadline.weight(.bold))
            Spacer()
        }
        .foregroundStyle(Color(red: 180.0/255, green: 118.0/255, blue: 0))
        .padding(12)
        .background(Color.brandOrange.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 汇总

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                (Text("\(Int(result.totalCalories.rounded()))")
                    .font(.system(size: 40, weight: .bold)).monospacedDigit()
                 + Text(" kcal")
                    .font(.headline).foregroundStyle(Color.inkTertiary))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                healthBadge
            }
            HStack(spacing: 10) {
                macroTile("蛋白质", result.totalProtein, tint: .brandGreen, labelColor: .brandGreenDeep)
                macroTile("脂肪", result.totalFat, tint: .brandCoral, labelColor: Color(red: 214.0/255, green: 74.0/255, blue: 42.0/255))
                macroTile("碳水", result.totalCarbs, tint: .brandOrange, labelColor: Color(red: 180.0/255, green: 118.0/255, blue: 0))
            }
        }
        .cardStyle()
    }

    private var healthBadge: some View {
        let color = HealthScore.color(result.healthScore)
        return VStack(spacing: 1) {
            Text("\(result.healthScore)/10")
                .font(.system(size: 15, weight: .heavy)).monospacedDigit()
            Text(HealthScore.label(result.healthScore))
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }

    private func macroTile(_ name: String, _ value: Double, tint: Color, labelColor: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))g")
                .font(.system(size: 18, weight: .heavy)).monospacedDigit()
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 识别项

    private var itemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                itemRow(index: index, item: item)
                if index < result.items.count - 1 {
                    Divider().overlay(Color.hairline)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private func itemRow(index: Int, item: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text("\(item.healthScore)")
                    .font(.caption.bold())
                    .frame(width: 24, height: 24)
                    .background(HealthScore.color(item.healthScore).opacity(0.16), in: Circle())
                    .foregroundStyle(HealthScore.color(item.healthScore))
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text("\(Int(item.grams.rounded()))g")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTertiary)
                Spacer(minLength: 6)
                (Text("\(Int(item.calories.rounded()))").font(.subheadline.weight(.bold)).monospacedDigit()
                 + Text(" kcal").font(.caption2).foregroundStyle(Color.inkTertiary))
                    .foregroundStyle(Color.inkPrimary)
            }
            if !item.alternatives.isEmpty {
                alternativeChips(for: index, item: item)
            }
        }
        .padding(.vertical, 13)
    }

    /// 易混项的候选切换：点一下即用候选的名称与营养替换该项（克数不变）。
    private func alternativeChips(for index: Int, item: FoodItem) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("也可能是")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.inkTertiary)
                ForEach(item.alternatives.indices, id: \.self) { altIndex in
                    Button {
                        result.items[index].selectAlternative(at: altIndex)
                    } label: {
                        Text(item.alternatives[altIndex].name)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Color.brandGreen.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.brandGreenDeep)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 34)
        }
    }

    // MARK: - 说明 / 元信息

    @ViewBuilder
    private var infoLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.assumptions.isEmpty {
                infoLine(icon: "scalemass", text: result.assumptions)
            }
            if !result.reason.isEmpty {
                infoLine(icon: "heart.text.square", text: result.reason)
            }
        }
        .padding(.horizontal, 4)
    }

    private func infoLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(Color.inkTertiary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private var metaLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("识别模型：\(modelName) · 数值为 AI 估算")
            if let usage = result.tokenUsage {
                Text("本次 Token：\(usage.total)（输入 \(usage.prompt) / 输出 \(usage.completion)）")
            } else {
                Text("本端点未返回 Token 用量")
            }
        }
        .font(.caption2)
        .foregroundStyle(Color.inkTertiary)
        .padding(.horizontal, 4)
    }
}

/// 健康评分的等级标签与配色。
enum HealthScore {
    static func label(_ score: Int) -> String {
        switch score {
        case 8...10: return String(localized: "优")
        case 6...7: return String(localized: "良")
        case 4...5: return String(localized: "中")
        default: return String(localized: "差")
        }
    }

    static func color(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 6...7: return .mint
        case 4...5: return .orange
        default: return .red
        }
    }
}

#Preview {
    ScrollView {
        RecognitionResultCard(result: .constant(RecognitionResult(
            items: [
                FoodItem(name: "米饭", grams: 150, caloriesPer100g: 130, proteinPer100g: 2.6, fatPer100g: 0.3, carbsPer100g: 28, healthScore: 5),
                FoodItem(
                    name: "牛奶", grams: 240, caloriesPer100g: 64, proteinPer100g: 3.3, fatPer100g: 3.6, carbsPer100g: 5,
                    healthScore: 8, healthReason: "蛋白质来源",
                    alternatives: [
                        FoodAlternative(name: "豆浆", caloriesPer100g: 31, proteinPer100g: 1.8, fatPer100g: 0.7, carbsPer100g: 3.7, healthScore: 8, healthReason: "植物蛋白"),
                        FoodAlternative(name: "燕麦奶", caloriesPer100g: 47, proteinPer100g: 1, fatPer100g: 1.5, carbsPer100g: 7, healthScore: 7, healthReason: "含膳食纤维"),
                    ]
                ),
            ],
            healthScore: 6,
            reason: "整体较均衡，可再补充一些蔬菜",
            recognitionConfidence: 0.6,
            portionAssumed: true,
            assumptions: "按一份约 250g 估算",
            modelUsed: "GPT-4o"
        )))
        .padding()
    }
    .background(Color.appBackground)
}
