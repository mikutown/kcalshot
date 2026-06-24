import Foundation
import Observation

/// 全局应用设置：非敏感项存 UserDefaults，API key 存 Keychain。
@Observable
final class AppSettings {
    private enum Keys {
        static let globalBaseURL = "global_base_url"
        static let healthSyncEnabled = "health_sync_enabled"
    }

    var globalBaseURL: String {
        didSet { UserDefaults.standard.set(globalBaseURL, forKey: Keys.globalBaseURL) }
    }

    /// 是否把每日热量同步到 Apple 健康。
    var healthSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(healthSyncEnabled, forKey: Keys.healthSyncEnabled) }
    }

    /// 全局 API key，读写直通 Keychain。
    var globalAPIKey: String {
        get { KeychainStore.get(account: KeychainStore.globalKeyAccount) ?? "" }
        set { KeychainStore.set(newValue, account: KeychainStore.globalKeyAccount) }
    }

    init() {
        self.globalBaseURL = UserDefaults.standard.string(forKey: Keys.globalBaseURL) ?? ""
        self.healthSyncEnabled = UserDefaults.standard.bool(forKey: Keys.healthSyncEnabled)
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
