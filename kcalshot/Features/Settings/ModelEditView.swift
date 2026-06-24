import SwiftUI
import SwiftData

struct ModelEditView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var allModels: [APIModelConfig]

    @Bindable var model: APIModelConfig

    @State private var overrideKey: String = ""
    @State private var showServerPicker = false

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("显示名", text: $model.displayName)
                TextField("Model ID", text: $model.modelId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    showServerPicker = true
                } label: {
                    Label("从服务器选择 Model ID", systemImage: "square.and.arrow.down")
                }
                Toggle("支持视觉（图片识别）", isOn: $model.supportsVision)
                Toggle("设为默认识别模型", isOn: isDefaultBinding)
            }

            Section {
                TextField("覆盖 Base URL（留空用全局）", text: overrideBaseURLBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("覆盖 API Key（留空用全局）", text: $overrideKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("覆盖 Endpoint（可选）")
            } footer: {
                Text("仅当此模型走与全局不同的 endpoint 时填写，例如本地 Ollama 或专用代理。")
            }

            Section {
                ConnectionTestButton {
                    settings.resolvedEndpoint(for: model)
                }
            } footer: {
                if !model.supportsVision {
                    Text("此模型标记为不支持视觉，将不能用于拍照识别。")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("编辑模型")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            overrideKey = KeychainStore.get(account: model.id.uuidString) ?? ""
        }
        .onChange(of: overrideKey) { _, newValue in
            KeychainStore.set(newValue, account: model.id.uuidString)
        }
        .sheet(isPresented: $showServerPicker) {
            let endpoint = settings.resolvedEndpoint(for: model)
            ModelPickerView(baseURL: endpoint.baseURL, apiKey: endpoint.apiKey) { id in
                model.modelId = id
                if model.displayName.isEmpty || model.displayName == "新模型" {
                    model.displayName = id
                }
                model.supportsVision = ModelHeuristics.likelyVision(id)
            }
        }
    }

    private var isDefaultBinding: Binding<Bool> {
        Binding(
            get: { model.isDefault },
            set: { newValue in
                if newValue {
                    for other in allModels where other.persistentModelID != model.persistentModelID {
                        other.isDefault = false
                    }
                }
                model.isDefault = newValue
            }
        )
    }

    private var overrideBaseURLBinding: Binding<String> {
        Binding(
            get: { model.overrideBaseURL ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                model.overrideBaseURL = trimmed.isEmpty ? nil : newValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        ModelEditView(model: APIModelConfig(displayName: "GPT-4o", modelId: "gpt-4o", isDefault: true))
    }
    .modelContainer(PreviewData.container)
    .environment(PreviewData.settings)
}
