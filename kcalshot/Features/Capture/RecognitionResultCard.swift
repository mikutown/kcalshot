import SwiftUI

struct RecognitionResultCard: View {
    let result: RecognitionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if result.needsReview {
                Label("建议核对份量/识别结果", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(result.totalCalories.rounded()))")
                    .font(.system(size: 40, weight: .bold))
                Text("kcal").foregroundStyle(.secondary)
                Spacer()
                healthBadge
            }

            HStack(spacing: 12) {
                macro("蛋白质", result.totalProtein)
                macro("脂肪", result.totalFat)
                macro("碳水", result.totalCarbs)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.items) { item in
                    HStack {
                        Text(item.name)
                        Text("\(Int(item.grams.rounded()))g")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(item.calories.rounded())) kcal")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }

            if !result.assumptions.isEmpty {
                infoLine(icon: "scalemass", text: result.assumptions)
            }
            if !result.reason.isEmpty {
                infoLine(icon: "heart.text.square", text: result.reason)
            }

            Text("识别模型：\(result.modelUsed.isEmpty ? "未知" : result.modelUsed) · 数值为 AI 估算")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var healthBadge: some View {
        VStack(spacing: 2) {
            Text("\(result.healthScore)/10")
                .font(.headline)
            Text(HealthScore.label(result.healthScore))
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(HealthScore.color(result.healthScore).opacity(0.18), in: Capsule())
        .foregroundStyle(HealthScore.color(result.healthScore))
    }

    private func macro(_ name: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))g").font(.headline)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func infoLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(text).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// 健康评分的等级标签与配色。
enum HealthScore {
    static func label(_ score: Int) -> String {
        switch score {
        case 8...10: return "优"
        case 6...7: return "良"
        case 4...5: return "中"
        default: return "差"
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
    RecognitionResultCard(result: RecognitionResult(
        items: [
            FoodItem(name: "米饭", grams: 150, caloriesPer100g: 130, proteinPer100g: 2.6, fatPer100g: 0.3, carbsPer100g: 28),
            FoodItem(name: "红烧肉", grams: 120, caloriesPer100g: 375, proteinPer100g: 15, fatPer100g: 32, carbsPer100g: 5),
        ],
        healthScore: 5,
        reason: "脂肪偏高，建议搭配蔬菜",
        recognitionConfidence: 0.6,
        portionAssumed: true,
        assumptions: "按一份约 250g 估算",
        modelUsed: "GPT-4o"
    ))
    .padding()
}
