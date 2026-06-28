import Foundation
import HealthKit

/// 与 Apple 健康交互：写入每日摄入热量，读取当天活动消耗。
enum HealthKitManager {
    private static let store = HKHealthStore()
    private static let energyType = HKQuantityType(.dietaryEnergyConsumed)
    private static let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    private static let bodyMassType = HKQuantityType(.bodyMass)
    private static let waterType = HKQuantityType(.dietaryWater)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 请求写入摄入热量 + 读取活动消耗与体重的授权。返回写入是否拿到（用户允许或已授权）。
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(
                toShare: [energyType, waterType],
                read: [activeEnergyType, bodyMassType]
            )
            return store.authorizationStatus(for: energyType) == .sharingAuthorized
        } catch {
            return false
        }
    }

    /// 读取 Apple 健康里的体重样本（含其他 App 同步进去的）。未授权时返回空。
    /// `since` 默认只取最近一个月，避免无界查询；传 nil 取全部历史。
    static func bodyMassSamples(
        since: Date? = Calendar.current.date(byAdding: .month, value: -1, to: .now)
    ) async -> [WeightPoint] {
        guard isAvailable else { return [] }
        let datePredicate = since.map { HKQuery.predicateForSamples(withStart: $0, end: nil) }
        let predicate = HKSamplePredicate.quantitySample(type: bodyMassType, predicate: datePredicate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        let unit = HKUnit.gramUnit(with: .kilo)
        return samples.map {
            WeightPoint(
                date: $0.startDate,
                weightKg: $0.quantity.doubleValue(for: unit),
                isLocal: false,
                localEntry: nil
            )
        }
    }

    /// 读取某天的活动消耗（kcal）。未授权读取时返回 0。
    static func activeEnergy(for date: Date) async -> Double {
        guard isAvailable else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let predicate = HKSamplePredicate.quantitySample(
            type: activeEnergyType,
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let descriptor = HKStatisticsQueryDescriptor(predicate: predicate, options: .cumulativeSum)
        let stats = try? await descriptor.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
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

    static var isWaterAuthorized: Bool {
        isAvailable && store.authorizationStatus(for: waterType) == .sharingAuthorized
    }

    /// 同步某天的饮水总量（毫升）：删除本 App 当天写入的旧样本，再写入一条新的总量。幂等。
    static func syncDailyWater(_ ml: Double, for date: Date) async {
        guard isWaterAuthorized else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = HKSamplePredicate.quantitySample(
            type: waterType,
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

        guard ml > 0 else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sampleDate = cal.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: sampleDate, end: sampleDate)
        try? await store.save(sample)
    }
}
