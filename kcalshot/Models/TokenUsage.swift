import Foundation
import SwiftData

/// 一次识别的 token 用量（瞬态值类型，可相加）。端点未返回用量时为 nil。
struct TokenCount: Equatable {
    var prompt: Int
    var completion: Int
    var total: Int

    static let zero = TokenCount(prompt: 0, completion: 0, total: 0)

    static func + (lhs: TokenCount, rhs: TokenCount) -> TokenCount {
        TokenCount(
            prompt: lhs.prompt + rhs.prompt,
            completion: lhs.completion + rhs.completion,
            total: lhs.total + rhs.total
        )
    }
}

/// 识别请求的种类。
enum RecognitionKind: String, Codable, CaseIterable {
    case photo
    case text

    var displayName: String {
        switch self {
        case .photo: return String(localized: "拍照")
        case .text: return String(localized: "文字")
        }
    }
}

/// 一条 token 用量记录（每次识别动作一条；高精度模式合并多次请求为一条）。
@Model
final class TokenUsage {
    var id: UUID
    var date: Date
    var modelDisplay: String
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int
    var kindRaw: String

    var kind: RecognitionKind {
        get { RecognitionKind(rawValue: kindRaw) ?? .photo }
        set { kindRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        modelDisplay: String,
        promptTokens: Int,
        completionTokens: Int,
        totalTokens: Int,
        kind: RecognitionKind
    ) {
        self.id = UUID()
        self.date = date
        self.modelDisplay = modelDisplay
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.kindRaw = kind.rawValue
    }
}

extension Array where Element == TokenUsage {
    /// 当天（同一自然日）的记录。
    func onSameDay(as date: Date) -> [TokenUsage] {
        let cal = Calendar.current
        return filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    var totalTokens: Int { reduce(0) { $0 + $1.totalTokens } }
}
