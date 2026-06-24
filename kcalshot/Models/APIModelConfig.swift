import Foundation
import SwiftData

/// 一个可用于识别的 LLM 模型配置。
/// API key 不存这里，存 Keychain（按 id 索引）。
@Model
final class APIModelConfig {
    var id: UUID
    var displayName: String
    var modelId: String
    var supportsVision: Bool
    var isDefault: Bool
    /// 为空则继承全局 base_url；填了则该模型用自己的 endpoint。
    var overrideBaseURL: String?

    init(
        displayName: String = "",
        modelId: String = "",
        supportsVision: Bool = true,
        isDefault: Bool = false,
        overrideBaseURL: String? = nil
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.modelId = modelId
        self.supportsVision = supportsVision
        self.isDefault = isDefault
        self.overrideBaseURL = overrideBaseURL
    }
}
