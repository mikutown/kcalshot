import SwiftUI

@Observable
@MainActor
final class RecognitionViewModel {
    enum State {
        case idle
        case recognizing
        case success(RecognitionResult)
        case failure(message: String, rawText: String?)
    }

    var state: State = .idle

    var isRecognizing: Bool {
        if case .recognizing = state { return true }
        return false
    }

    func recognize(image: UIImage, model: APIModelConfig, settings: AppSettings) async {
        state = .recognizing
        guard let uri = ImageEncoder.base64DataURI(from: image) else {
            state = .failure(message: "图片处理失败", rawText: nil)
            return
        }
        let endpoint = settings.resolvedEndpoint(for: model)
        let client = LLMClient(baseURL: endpoint.baseURL, apiKey: endpoint.apiKey)
        do {
            let result = try await client.recognize(
                imageDataURI: uri,
                modelId: model.modelId,
                modelDisplayName: model.displayName
            )
            state = .success(result)
        } catch {
            let llm = error as? LLMError
            state = .failure(
                message: llm?.errorDescription ?? error.localizedDescription,
                rawText: llm?.rawText
            )
        }
    }
}
