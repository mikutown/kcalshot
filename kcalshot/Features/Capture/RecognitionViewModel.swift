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

    /// 识别中的细分阶段，用于显示进度、减少等待焦虑。
    enum Phase {
        case preparing
        case uploading(Double)
        case waiting
    }

    var state: State = .idle
    var phase: Phase = .preparing

    var isRecognizing: Bool {
        if case .recognizing = state { return true }
        return false
    }

    func recognize(image: UIImage, model: APIModelConfig, settings: AppSettings, correction: String? = nil) async {
        state = .recognizing
        phase = .preparing
        // 降采样 + JPEG + base64 是 CPU 活，放后台跑，别卡主线程。
        let uri = await Task.detached(priority: .userInitiated) {
            ImageEncoder.base64DataURI(from: image)
        }.value
        guard let uri else {
            state = .failure(message: "图片处理失败", rawText: nil)
            return
        }
        phase = .uploading(0)
        let endpoint = settings.resolvedEndpoint(for: model)
        let client = LLMClient(baseURL: endpoint.baseURL, apiKey: endpoint.apiKey)
        await run {
            try await client.recognize(
                imageDataURI: uri,
                modelId: model.modelId,
                modelDisplayName: model.displayName,
                correction: correction,
                onUploadProgress: { [weak self] fraction in
                    Task { @MainActor in
                        self?.phase = fraction >= 1 ? .waiting : .uploading(fraction)
                    }
                }
            )
        }
    }

    func recognizeText(description: String, model: APIModelConfig, settings: AppSettings) async {
        state = .recognizing
        phase = .waiting
        let endpoint = settings.resolvedEndpoint(for: model)
        let client = LLMClient(baseURL: endpoint.baseURL, apiKey: endpoint.apiKey)
        await run {
            try await client.recognizeText(
                description: description,
                modelId: model.modelId,
                modelDisplayName: model.displayName
            )
        }
    }

    private func run(_ work: () async throws -> RecognitionResult) async {
        do {
            state = .success(try await work())
        } catch {
            let llm = error as? LLMError
            state = .failure(
                message: llm?.errorDescription ?? error.localizedDescription,
                rawText: llm?.rawText
            )
        }
    }
}
