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
        }
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
            // 200 但不是标准 /models 结构：仍视为连通成功。
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
}
