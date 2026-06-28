import Foundation
import Observation

/// 全局应用设置：非敏感项存 UserDefaults，API key 存 Keychain。
@Observable
final class AppSettings {
    private enum Keys {
        static let globalBaseURL = "global_base_url"
        static let healthSyncEnabled = "health_sync_enabled"
        static let waterTargetML = "water_target_ml"
        static let highPrecisionMode = "high_precision_mode"
        static let precisionSampleCount = "precision_sample_count"
    }

    var globalBaseURL: String {
        didSet { UserDefaults.standard.set(globalBaseURL, forKey: Keys.globalBaseURL) }
    }

    /// 是否把每日热量同步到 Apple 健康。
    var healthSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(healthSyncEnabled, forKey: Keys.healthSyncEnabled) }
    }

    /// 每日饮水目标（毫升）。
    var waterTargetML: Double {
        didSet { UserDefaults.standard.set(waterTargetML, forKey: Keys.waterTargetML) }
    }

    /// 高精度模式：同一张照片多次采样后取中位数聚合（成本/延迟翻倍）。
    var highPrecisionMode: Bool {
        didSet { UserDefaults.standard.set(highPrecisionMode, forKey: Keys.highPrecisionMode) }
    }

    /// 高精度模式的采样次数。
    var precisionSampleCount: Int {
        didSet { UserDefaults.standard.set(precisionSampleCount, forKey: Keys.precisionSampleCount) }
    }

    /// 全局 API key，读写直通 Keychain。
    var globalAPIKey: String {
        get { KeychainStore.get(account: KeychainStore.globalKeyAccount) ?? "" }
        set { KeychainStore.set(newValue, account: KeychainStore.globalKeyAccount) }
    }

    init() {
        self.globalBaseURL = UserDefaults.standard.string(forKey: Keys.globalBaseURL) ?? ""
        self.healthSyncEnabled = UserDefaults.standard.bool(forKey: Keys.healthSyncEnabled)
        let storedTarget = UserDefaults.standard.double(forKey: Keys.waterTargetML)
        self.waterTargetML = storedTarget > 0 ? storedTarget : 2000
        self.highPrecisionMode = UserDefaults.standard.bool(forKey: Keys.highPrecisionMode)
        let storedSamples = UserDefaults.standard.integer(forKey: Keys.precisionSampleCount)
        self.precisionSampleCount = storedSamples > 0 ? storedSamples : 3
    }

    /// 解析某模型实际生效的 base_url 与 key（覆盖优先，否则用全局）。
    func resolvedEndpoint(for config: APIModelConfig) -> (baseURL: String, apiKey: String) {
        let override = config.overrideBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = (override?.isEmpty == false ? override! : globalBaseURL)
        let overrideKey = KeychainStore.get(account: config.id.uuidString)
        let apiKey = (overrideKey?.isEmpty == false ? overrideKey! : globalAPIKey)
        return (baseURL, apiKey)
    }
}
