import SwiftUI
import SwiftData

struct ModelListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \APIModelConfig.displayName) private var models: [APIModelConfig]

    @State private var newModelID: PersistentIdentifier?
    @State private var showServerPicker = false

    var body: some View {
        List {
            if models.isEmpty {
                ContentUnavailableView(
                    "还没有模型",
                    systemImage: "cpu",
                    description: Text("请点击右上角「+」添加用于识别的模型")
                )
            } else {
                ForEach(models) { model in
                    NavigationLink {
                        ModelEditView(model: model)
                    } label: {
                        row(for: model)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("模型管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showServerPicker = true
                    } label: {
                        Label("从服务器选择", systemImage: "square.and.arrow.down")
                    }
                    Button(action: addModel) {
                        Label("手动添加", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(item: $newModelID) { id in
            if let model = models.first(where: { $0.persistentModelID == id }) {
                ModelEditView(model: model)
            }
        }
        .sheet(isPresented: $showServerPicker) {
            ModelPickerView(baseURL: settings.globalBaseURL, apiKey: settings.globalAPIKey) { id in
                addFromServer(id)
            }
        }
    }

    private func row(for model: APIModelConfig) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(model.displayName.isEmpty ? "(未命名)" : model.displayName)
                if model.isDefault {
                    Text("默认")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            HStack(spacing: 6) {
                Text(model.modelId.isEmpty ? "未设置 Model ID" : model.modelId)
                if !model.supportsVision {
                    Text("· 不支持视觉").foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func addModel() {
        let model = APIModelConfig(displayName: "新模型", supportsVision: true, isDefault: models.isEmpty)
        context.insert(model)
        newModelID = model.persistentModelID
    }

    private func addFromServer(_ id: String) {
        let model = APIModelConfig(
            displayName: id,
            modelId: id,
            supportsVision: ModelHeuristics.likelyVision(id),
            isDefault: models.isEmpty
        )
        context.insert(model)
        newModelID = model.persistentModelID
    }

    private func delete(at offsets: IndexSet) {
        let removed = offsets.map { models[$0] }
        let removingDefault = removed.contains { $0.isDefault }
        let removedIDs = Set(removed.map { $0.persistentModelID })
        for model in removed {
            KeychainStore.delete(account: model.id.uuidString)
            context.delete(model)
        }
        // 若删掉了默认模型，把剩下的第一个设为默认。
        if removingDefault,
           let first = models.first(where: { !removedIDs.contains($0.persistentModelID) }) {
            first.isDefault = true
        }
    }
}

#Preview {
    NavigationStack {
        ModelListView()
    }
    .modelContainer(PreviewData.container)
    .environment(PreviewData.settings)
}
