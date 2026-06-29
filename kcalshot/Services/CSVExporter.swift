import Foundation

/// 把记录导出为 CSV 临时文件，供系统分享面板使用。
enum CSVExporter {
    private static let iso = ISO8601DateFormatter()

    /// 转义单个字段：先中和表格公式注入（=,+,-,@,制表/回车 开头的值在 Excel/Sheets 会被当公式执行），
    /// 再在含逗号/引号/换行时用引号包裹并转义内部引号。
    private static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, "=+-@\t\r".contains(first) {
            value = "'" + value
        }
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// 写盘是磁盘 I/O，放到后台优先级线程，避免在主线程造成卡顿。字符串拼装在调用方（主线程）完成。
    private static func write(_ content: String, filename: String) async throws -> URL {
        try await Task.detached(priority: .utility) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        }.value
    }

    static func exportMeals(_ entries: [MealEntry]) async throws -> URL {
        var lines = [row(["date", "meal", "name", "calories", "protein", "fat", "carbs", "healthScore", "note"])]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            lines.append(row([
                iso.string(from: e.date),
                e.mealType.rawValue,
                e.name,
                String(Int(e.calories.rounded())),
                String(Int(e.protein.rounded())),
                String(Int(e.fat.rounded())),
                String(Int(e.carbs.rounded())),
                String(e.healthScore),
                e.note,
            ]))
        }
        return try await write(lines.joined(separator: "\n"), filename: "kcalshot-meals.csv")
    }

    static func exportWeights(_ entries: [WeightEntry]) async throws -> URL {
        var lines = [row(["date", "weightKg"])]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            lines.append(row([iso.string(from: e.date), String(format: "%.1f", e.weightKg)]))
        }
        return try await write(lines.joined(separator: "\n"), filename: "kcalshot-weights.csv")
    }

    static func exportWaters(_ entries: [WaterEntry]) async throws -> URL {
        var lines = [row(["date", "amountML"])]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            lines.append(row([iso.string(from: e.date), String(Int(e.amountML.rounded()))]))
        }
        return try await write(lines.joined(separator: "\n"), filename: "kcalshot-water.csv")
    }

    static func exportTokens(_ entries: [TokenUsage]) async throws -> URL {
        var lines = [row(["date", "model", "prompt", "completion", "total", "kind"])]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            lines.append(row([
                iso.string(from: e.date),
                e.modelDisplay,
                String(e.promptTokens),
                String(e.completionTokens),
                String(e.totalTokens),
                e.kindRaw,
            ]))
        }
        return try await write(lines.joined(separator: "\n"), filename: "kcalshot-tokens.csv")
    }
}
