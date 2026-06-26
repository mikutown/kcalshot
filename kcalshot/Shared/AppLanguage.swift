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
