import Foundation
import SwiftData

/// 一条喝水记录（毫升）。
@Model
final class WaterEntry {
    var id: UUID
    var date: Date
    var amountML: Double

    init(date: Date = .now, amountML: Double = 250) {
        self.id = UUID()
        self.date = date
        self.amountML = amountML
    }
}

extension Array where Element == WaterEntry {
    /// 当天（同一自然日）的喝水记录。
    func onSameDay(as date: Date) -> [WaterEntry] {
        let cal = Calendar.current
        return filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    var totalML: Double { reduce(0) { $0 + $1.amountML } }
}
