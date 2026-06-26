import SwiftUI

/// 从 endpoint 拉取 /models 列表，可搜索 + 视觉过滤，点选返回 model id。
struct ModelPickerView: View {
    let baseURL: String
    let apiKey: String
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allIDs: [String] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var visionOnly = true

    private var filtered: [String] {
        allIDs.filter { id in
            (!visionOnly || ModelHeuristics.likelyVision(id)) &&
            (search.isEmpty || id.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("选择模型")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView("加载模型列表…")
        } else if let errorMessage {
            ContentUnavailableView {
                Label("无法获取模型列表", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("重试") { Task { await load() } }
            }
        } else {
            List {
                Section {
                    Toggle("仅显示可能支持视觉的模型", isOn: $visionOnly)
                } footer: {
                    Text("共 \(allIDs.count) 个模型，当前显示 \(filtered.count) 个。视觉判断为启发式，选择后可在编辑页手动调整。")
                }
                Section {
                    ForEach(filtered, id: \.self) { id in
                        Button {
                            onSelect(id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(id).foregroundStyle(.primary)
                                Spacer()
                                if ModelHeuristics.likelyVision(id) {
                                    Image(systemName: "eye")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "搜索 Model ID")
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            let ids = try await LLMClient(baseURL: baseURL, apiKey: apiKey).listModels()
            allIDs = ids.sorted()
            if ids.isEmpty {
                errorMessage = "该 endpoint 未返回模型列表"
            }
        } catch {
            errorMessage = (error as? LLMError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}
