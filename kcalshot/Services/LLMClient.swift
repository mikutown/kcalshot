import Foundation

/// 可区分的 API 错误，用于给用户可操作的提示。
enum LLMError: LocalizedError {
    case invalidBaseURL
    case missingAPIKey
    case unauthorized
    case unreachable(String)
    case badStatus(Int, String?)
    case decoding
    case unsupportedEndpoint
    case htmlResponse
    case emptyResponse
    case unparseableResult(raw: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Base URL 无效，请检查格式（例如 https://api.openai.com/v1）"
        case .missingAPIKey:
            return "缺少 API key"
        case .unauthorized:
            return "鉴权失败：API key 无效或无权限（401/403）"
        case .unreachable(let detail):
            return "无法连接到 endpoint：\(detail)"
        case .badStatus(let code, let body):
            if let body, !body.isEmpty {
                return "服务返回错误 \(code)：\(body)"
            }
            return "服务返回错误状态码 \(code)"
        case .decoding:
            return "返回内容无法解析"
        case .unsupportedEndpoint:
            return "该 endpoint 未实现 /models 接口"
        case .htmlResponse:
            return "返回的是网页而非 API 数据，Base URL 可能不对（例如缺少 /v1）"
        case .emptyResponse:
            return "模型未返回内容"
        case .unparseableResult:
            return "模型返回的内容不是有效 JSON，可重试或换模型"
        }
    }

    /// 解析失败时保留模型原始文本，供手动录入。
    var rawText: String? {
        if case .unparseableResult(let raw) = self { return raw }
        return nil
    }
}

/// 最小 LLM 网络层。M1 仅实现测试连接（GET /models）。
struct LLMClient {
    let baseURL: String
    let apiKey: String

    private struct ModelsResponse: Decodable {
        struct Model: Decodable { let id: String }
        let data: [Model]
    }

    private func makeURL(path: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let base = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: base + path)
    }

    /// 轻量连通性测试：GET /models。成功返回模型 id 列表。
    func testConnection() async throws -> [String] {
        guard let url = makeURL(path: "/models") else { throw LLMError.invalidBaseURL }
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.unreachable(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw LLMError.decoding }

        switch http.statusCode {
        case 200...299:
            if let parsed = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
                return parsed.data.map(\.id)
            }
            if Self.looksLikeHTML(data) { throw LLMError.htmlResponse }
            // 200 且非 HTML、但不是标准 /models 结构：仍视为连通成功。
            return []
        case 401, 403:
            throw LLMError.unauthorized
        case 404:
            throw LLMError.unsupportedEndpoint
        default:
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw LLMError.badStatus(http.statusCode, body.map { String($0.prefix(200)) })
        }
    }

    /// 拉取可用模型 id 列表（GET /models）。
    func listModels() async throws -> [String] {
        try await testConnection()
    }

    // MARK: - 视觉识别

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    /// 用视觉模型识别一张食物照片，解析为 RecognitionResult。
    func recognize(
        imageDataURI: String,
        modelId: String,
        modelDisplayName: String,
        correction: String? = nil
    ) async throws -> RecognitionResult {
        try await recognizeShared(modelId: modelId, modelDisplayName: modelDisplayName) {
            [
                ["role": "system", "content": RecognitionPrompt.system(forText: false)],
                ["role": "user", "content": [
                    ["type": "text", "text": RecognitionPrompt.photoUserInstruction(correction: correction)],
                    ["type": "image_url", "image_url": ["url": imageDataURI]],
                ]],
            ]
        }
    }

    /// 用文字描述解析这一餐，解析为 RecognitionResult。
    func recognizeText(
        description: String,
        modelId: String,
        modelDisplayName: String
    ) async throws -> RecognitionResult {
        try await recognizeShared(modelId: modelId, modelDisplayName: modelDisplayName) {
            [
                ["role": "system", "content": RecognitionPrompt.system(forText: true)],
                ["role": "user", "content": RecognitionPrompt.textUserInstruction(description)],
            ]
        }
    }

    /// 解析失败会重试一次；仍失败抛出 .unparseableResult（带原始文本）。
    private func recognizeShared(
        modelId: String,
        modelDisplayName: String,
        messages: () -> [[String: Any]]
    ) async throws -> RecognitionResult {
        var lastRaw = ""
        for attempt in 0..<2 {
            let raw = try await postChat(modelId: modelId, messages: messages(), attempt: attempt)
            lastRaw = raw
            if let result = RecognitionResult.parse(from: raw, modelUsed: modelDisplayName) {
                return result
            }
        }
        throw LLMError.unparseableResult(raw: lastRaw)
    }

    private func postChat(modelId: String, messages: [[String: Any]], attempt: Int) async throws -> String {
        guard let url = makeURL(path: "/chat/completions") else { throw LLMError.invalidBaseURL }
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        let body: [String: Any] = [
            "model": modelId,
            "messages": messages,
            "max_tokens": 1200,
            // 重试时温度归零，尽量稳定输出。
            "temperature": attempt == 0 ? 0.2 : 0.0,
            "stream": false,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.unreachable(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw LLMError.decoding }
        switch http.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw LLMError.unauthorized
        default:
            let bodyText = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw LLMError.badStatus(http.statusCode, bodyText.map { String($0.prefix(200)) })
        }

        if Self.looksLikeHTML(data) { throw LLMError.htmlResponse }
        guard let parsed = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = parsed.choices.first?.message.content,
              !content.isEmpty else {
            throw LLMError.emptyResponse
        }
        return content
    }

    private static func looksLikeHTML(_ data: Data) -> Bool {
        guard let text = String(data: data.prefix(512), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return text.hasPrefix("<!doctype html") || text.hasPrefix("<html")
    }
}
