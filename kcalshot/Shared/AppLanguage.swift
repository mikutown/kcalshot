import Foundation

/// App 界面语言的单一事实来源。识别输出语言据此决定（而非系统语言）。
enum AppLanguage: String {
    case chinese
    case english

    /// 当前界面语言。目前界面为中文硬编码；接入真正的双语 UI 后，
    /// 改为读取已解析的本地化语言（Bundle.main.preferredLocalizations）或用户设置。
    static var current: AppLanguage { .chinese }

    /// 写进 prompt 的语言名。
    var outputName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}
