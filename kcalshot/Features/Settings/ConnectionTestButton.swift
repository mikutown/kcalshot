import SwiftUI

/// 复用的"测试连接"按钮 + 状态反馈。
struct ConnectionTestButton: View {
    /// 返回当前要测试的 endpoint（base_url + key）。
    let endpoint: () -> (baseURL: String, apiKey: String)

    @State private var state: TestState = .idle

    enum TestState {
        case idle
        case testing
        case success(modelCount: Int)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await run() }
            } label: {
                HStack {
                    if case .testing = state {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "bolt.horizontal.circle")
                    }
                    Text("测试连接")
                }
            }
            .disabled(isTesting)

            statusView
        }
    }

    private var isTesting: Bool {
        if case .testing = state { return true }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        switch state {
        case .idle:
            EmptyView()
        case .testing:
            Text("正在测试…").font(.footnote).foregroundStyle(.secondary)
        case .success(let count):
            Label(
                count > 0 ? "连接成功，发现 \(count) 个模型" : "连接成功",
                systemImage: "checkmark.circle.fill"
            )
            .font(.footnote)
            .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private func run() async {
        let ep = endpoint()
        state = .testing
        do {
            let ids = try await LLMClient(baseURL: ep.baseURL, apiKey: ep.apiKey).testConnection()
            state = .success(modelCount: ids.count)
        } catch {
            let message = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            state = .failure(message)
        }
    }
}
