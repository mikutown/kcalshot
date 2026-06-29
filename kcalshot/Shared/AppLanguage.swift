import Foundation

/// App 界面语言的单一事实来源。识别输出语言据此决定。
enum AppLanguage: String {
    case chinese
    case english

    /// 当前界面语言：取 App 实际解析到的本地化语言（en / zh-Hans），
    /// 与用户看到的界面一致，因此识别输出语言跟随界面语言。
    static var current: AppLanguage {
        let code = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        return code.hasPrefix("en") ? .english : .chinese
    }

    /// 写进 prompt 的语言名。
    var outputName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}

/// 用户在设置里选择的界面语言偏好（含「跟随系统」退路）。
/// 通过写入 AppleLanguages 生效，需重启 App 后全部文案（含 String(localized:)）才一致切换。
enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "跟随系统")
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }

    /// 写进 AppleLanguages 的语言码；system 返回 nil 表示移除覆盖、回到系统语言。
    var languageCode: String? {
        switch self {
        case .system: return nil
        case .chinese: return "zh-Hans"
        case .english: return "en"
        }
    }
}
