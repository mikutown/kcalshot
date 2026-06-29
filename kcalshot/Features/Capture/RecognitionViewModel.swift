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

    /// 高精度模式下的采样进度（已完成 / 总数）；总数为 0 表示非多采样。
    var samplesDone: Int = 0
    var samplesTotal: Int = 0

    var isRecognizing: Bool {
        if case .recognizing = state { return true }
        return false
    }

    /// 成功结果的可写视图：供结果卡片切换易混候选后写回。
    var successResult: RecognitionResult? {
        get {
            if case .success(let result) = state { return result }
            return nil
        }
        set {
            if let newValue { state = .success(newValue) }
        }
    }

    func recognize(image: UIImage, model: APIModelConfig, settings: AppSettings, correction: String? = nil) async {
        state = .recognizing
        phase = .preparing
        samplesDone = 0
        samplesTotal = 0
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

        if settings.highPrecisionMode && settings.precisionSampleCount > 1 {
            await runHighPrecision(
                client: client,
                count: settings.precisionSampleCount,
                imageDataURI: uri,
                modelId: model.modelId,
                modelDisplayName: model.displayName,
                correction: correction
            )
            return
        }

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

    /// 高精度：并行多次采样，聚合取中位数。部分失败仍用剩余结果聚合；全失败按失败处理。
    private func runHighPrecision(
        client: LLMClient,
        count: Int,
        imageDataURI: String,
        modelId: String,
        modelDisplayName: String,
        correction: String?
    ) async {
        samplesTotal = count
        samplesDone = 0
        phase = .waiting

        let results = await withTaskGroup(of: RecognitionResult?.self) { group -> [RecognitionResult] in
            for _ in 0..<count {
                group.addTask {
                    try? await client.recognize(
                        imageDataURI: imageDataURI,
                        modelId: modelId,
                        modelDisplayName: modelDisplayName,
                        correction: correction
                    )
                }
            }
            var collected: [RecognitionResult] = []
            for await result in group {
                if let result { collected.append(result) }
                samplesDone += 1
            }
            return collected
        }

        if var aggregated = RecognitionAggregator.aggregate(results) {
            // 多次采样的 token 要全部加总（聚合只挑一条做基准，会丢掉其余请求的用量）。
            let summed = results.compactMap(\.tokenUsage).reduce(into: nil as TokenCount?) {
                $0 = ($0 ?? .zero) + $1
            }
            aggregated.tokenUsage = summed
            state = .success(aggregated)
        } else {
            state = .failure(
                message: String(localized: "多次识别均未成功，请重试或关闭高精度模式"),
                rawText: nil
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
