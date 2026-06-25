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
