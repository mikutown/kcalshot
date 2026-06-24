import Foundation

/// 一次识别的完整结果（瞬态，保存时转为 MealEntry）。
struct RecognitionResult: Equatable {
    var items: [FoodItem]
    /// 1...10，10 = 最健康
    var healthScore: Int
    var reason: String
    /// 0...1，模型自报"认得准不准"
    var recognitionConfidence: Double
    /// 份量是否为模型假设
    var portionAssumed: Bool
    /// 份量/估算假设说明
    var assumptions: String
    /// 识别所用模型显示名
    var modelUsed: String

    var totalCalories: Double { items.totalCalories }
    var totalProtein: Double { items.totalProtein }
    var totalFat: Double { items.totalFat }
    var totalCarbs: Double { items.totalCarbs }

    /// 启发式：是否需要提醒用户核对（见 PRD F3.1）。
    var needsReview: Bool {
        recognitionConfidence < 0.7 || portionAssumed || items.count > 2
    }
}

// MARK: - 容错 JSON 解码

/// 从 keyed 容器解码 Double，容忍 Double / Int / String 三种形态。
private func lenientDouble<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
    if let d = try? c.decode(Double.self, forKey: key) { return d }
    if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
    if let s = try? c.decode(String.self, forKey: key) {
        let cleaned = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }
    return nil
}

extension RecognitionResult {
    /// 模型返回的原始 JSON 结构。数值字段容忍 Double/Int/String。
    private struct Payload: Decodable {
        struct Item: Decodable {
            var name: String
            var grams: Double
            var caloriesPer100g: Double
            var proteinPer100g: Double
            var fatPer100g: Double
            var carbsPer100g: Double

            enum CodingKeys: String, CodingKey {
                case name, grams, caloriesPer100g, proteinPer100g, fatPer100g, carbsPer100g
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                name = (try? c.decode(String.self, forKey: .name)) ?? "未知食物"
                grams = max(lenientDouble(c, .grams) ?? 100, 0)
                caloriesPer100g = lenientDouble(c, .caloriesPer100g) ?? 0
                proteinPer100g = lenientDouble(c, .proteinPer100g) ?? 0
                fatPer100g = lenientDouble(c, .fatPer100g) ?? 0
                carbsPer100g = lenientDouble(c, .carbsPer100g) ?? 0
            }
        }

        var items: [Item]
        var healthScore: Int
        var reason: String
        var recognitionConfidence: Double
        var portionAssumed: Bool
        var assumptions: String

        enum CodingKeys: String, CodingKey {
            case items, healthScore, reason, recognitionConfidence, portionAssumed, assumptions
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            items = (try? c.decode([Item].self, forKey: .items)) ?? []
            healthScore = Int((lenientDouble(c, .healthScore) ?? 5).rounded())
            reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
            recognitionConfidence = lenientDouble(c, .recognitionConfidence) ?? 0.5
            portionAssumed = (try? c.decode(Bool.self, forKey: .portionAssumed)) ?? true
            assumptions = (try? c.decode(String.self, forKey: .assumptions)) ?? ""
        }
    }

    /// 从模型返回文本解析。容忍代码围栏与前后噪声。返回 nil 表示解析失败。
    static func parse(from raw: String, modelUsed: String) -> RecognitionResult? {
        guard let jsonData = extractJSON(from: raw) else { return nil }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: jsonData) else { return nil }
        let items = payload.items.map {
            FoodItem(
                name: $0.name,
                grams: $0.grams,
                caloriesPer100g: $0.caloriesPer100g,
                proteinPer100g: $0.proteinPer100g,
                fatPer100g: $0.fatPer100g,
                carbsPer100g: $0.carbsPer100g
            )
        }
        guard !items.isEmpty else { return nil }
        return RecognitionResult(
            items: items,
            healthScore: min(max(payload.healthScore, 1), 10),
            reason: payload.reason,
            recognitionConfidence: min(max(payload.recognitionConfidence, 0), 1),
            portionAssumed: payload.portionAssumed,
            assumptions: payload.assumptions,
            modelUsed: modelUsed
        )
    }

    /// 从可能含 ```json 围栏或额外文字的字符串中提取 JSON 对象。
    private static func extractJSON(from raw: String) -> Data? {
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end {
            return String(raw[start...end]).data(using: .utf8)
        }
        return nil
    }
}
