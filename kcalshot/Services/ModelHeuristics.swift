import Foundation

/// 基于模型 id 的启发式判断（仅辅助默认值，用户可覆盖）。
enum ModelHeuristics {
    /// 明显不是视觉对话模型的关键词（图像生成 / 视频 / 音乐 / 语音 / 向量等）。
    private static let nonVision = [
        "image", "flux", "seedream", "seedance", "veo", "suno", "sora",
        "tts", "whisper", "embedding", "rerank", "音乐", "imagen", "jimeng", "z-image",
    ]

    /// 常见支持视觉的模型家族关键词。
    private static let vision = [
        "vl", "vision", "gpt-4o", "gpt-4.1", "gpt-5", "o3", "o4",
        "claude-3", "claude-sonnet", "claude-opus", "claude-haiku",
        "gemini", "grok-4", "qvq", "doubao", "glm-4v", "glm-4.5v",
    ]

    static func likelyVision(_ modelID: String) -> Bool {
        let s = modelID.lowercased()
        if nonVision.contains(where: s.contains) { return false }
        return vision.contains(where: s.contains)
    }
}
