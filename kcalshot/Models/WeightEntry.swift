import Foundation
import SwiftData

/// 一条体重记录。
@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weightKg: Double

    init(date: Date = .now, weightKg: Double = 60) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
    }
}

/// 展示用的体重点：可能来自本地记录，也可能来自 Apple 健康（其他 App 同步进去的）。
struct WeightPoint: Identifiable {
    let date: Date
    let weightKg: Double
    let isLocal: Bool
    /// 本地来源时持有原记录，便于删除。
    let localEntry: WeightEntry?

    var id: String { (isLocal ? "L-" : "H-") + String(date.timeIntervalSince1970) }

    /// 合并本地记录与健康样本：同一天若有本地记录则以本地为准，健康每天取最新一条。
    static func merged(local: [WeightEntry], health: [WeightPoint]) -> [WeightPoint] {
        let cal = Calendar.current
        let localDays = Set(local.map { cal.startOfDay(for: $0.date) })
        var points = local.map {
            WeightPoint(date: $0.date, weightKg: $0.weightKg, isLocal: true, localEntry: $0)
        }
        let healthByDay = Dictionary(grouping: health) { cal.startOfDay(for: $0.date) }
        for (day, samples) in healthByDay {
            guard !localDays.contains(day),
                  let latest = samples.max(by: { $0.date < $1.date }) else { continue }
            points.append(latest)
        }
        return points.sorted { $0.date < $1.date }
    }
}
