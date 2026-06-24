import Foundation
import HealthKit

/// 把每日摄入热量写入 Apple 健康（仅写、不读）。
enum HealthKitManager {
    private static let store = HKHealthStore()
    private static let energyType = HKQuantityType(.dietaryEnergyConsumed)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 请求写入授权。返回是否拿到（用户允许或已授权）。
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [energyType], read: [])
            return store.authorizationStatus(for: energyType) == .sharingAuthorized
        } catch {
            return false
        }
    }

    static var isAuthorized: Bool {
        isAvailable && store.authorizationStatus(for: energyType) == .sharingAuthorized
    }

    /// 同步某天的摄入总热量：删除本 App 当天写入的旧样本，再写入一条新的总量。
    /// 幂等，可在记录变化时随时调用。
    static func syncDailyTotal(_ kcal: Double, for date: Date) async {
        guard isAuthorized else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        // 删除本 App 当天写入的旧样本，避免重复累加。
        let predicate = HKSamplePredicate.quantitySample(
            type: energyType,
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let descriptor = HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: [])
        let mine = HKSource.default()
        if let existing = try? await descriptor.result(for: store) {
            let ours = existing.filter { $0.sourceRevision.source == mine }
            if !ours.isEmpty {
                try? await store.delete(ours)
            }
        }

        guard kcal > 0 else { return }
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        // 样本时间放在当天中午，确保归入该自然日。
        let sampleDate = cal.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
        let sample = HKQuantitySample(type: energyType, quantity: quantity, start: sampleDate, end: sampleDate)
        try? await store.save(sample)
    }
}
