import SwiftUI
import SwiftData
import PhotosUI

struct CaptureView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \APIModelConfig.displayName) private var models: [APIModelConfig]

    @State private var image: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedModel: APIModelConfig?
    @State private var showCamera = false
    @State private var vm = RecognitionViewModel()
    @State private var draft: SaveDraft?

    /// 待保存草稿（Identifiable，配合 .sheet(item:) 避免空白页竞态）。
    private struct SaveDraft: Identifiable {
        let id = UUID()
        let entry: MealEntry
        let needsReview: Bool
    }

    private var visionModels: [APIModelConfig] {
        models.filter { $0.supportsVision && !$0.modelId.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    imageArea
                    pickerButtons

                    if visionModels.isEmpty {
                        noModelHint
                    } else {
                        modelPicker
                        recognizeButton
                        resultArea
                    }
                }
                .padding()
            }
            .navigationTitle("识别食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task { await loadImage(from: newItem) }
            }
            .onAppear {
                if selectedModel == nil {
                    selectedModel = visionModels.first(where: { $0.isDefault }) ?? visionModels.first
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { picked in
                    image = picked
                    vm.state = .idle
                }
                .ignoresSafeArea()
            }
            .sheet(item: $draft) { draft in
                NavigationStack {
                    MealEditView(
                        entry: draft.entry,
                        isNew: true,
                        needsReview: draft.needsReview,
                        onFinish: { dismiss() }
                    )
                }
            }
        }
    }

    private func prepareSave(_ result: RecognitionResult) {
        let entry = MealEntry(
            date: .now,
            mealType: .suggested(),
            name: result.items.map(\.name).joined(separator: "、"),
            items: result.items,
            healthScore: result.healthScore,
            note: "",
            thumbnailData: image.flatMap { ImageEncoder.thumbnailData(from: $0) },
            modelUsed: result.modelUsed
        )
        draft = SaveDraft(entry: entry, needsReview: result.needsReview)
    }

    @ViewBuilder
    private var imageArea: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 220)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus").font(.largeTitle)
                        Text("选择或拍摄一张食物照片").foregroundStyle(.secondary)
                    }
                }
        }
    }

    private var pickerButtons: some View {
        HStack {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("相册", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                showCamera = true
            } label: {
                Label("拍照", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!CameraPicker.isAvailable)
        }
    }

    private var modelPicker: some View {
        HStack {
            Text("识别模型").foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(visionModels) { model in
                    Button {
                        selectedModel = model
                    } label: {
                        if model.persistentModelID == selectedModel?.persistentModelID {
                            Label(model.displayName, systemImage: "checkmark")
                        } else {
                            Text(model.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedModel?.displayName ?? "选择模型")
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var recognizeButton: some View {
        Button {
            guard let image, let model = selectedModel else { return }
            Task { await vm.recognize(image: image, model: model, settings: settings) }
        } label: {
            HStack {
                if vm.isRecognizing { ProgressView().controlSize(.small) }
                Text(isReRecognize ? "换模型重新识别" : "识别")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(image == nil || selectedModel == nil || vm.isRecognizing)
    }

    private var isReRecognize: Bool {
        if case .success = vm.state { return true }
        if case .failure = vm.state { return true }
        return false
    }

    @ViewBuilder
    private var resultArea: some View {
        switch vm.state {
        case .idle:
            EmptyView()
        case .recognizing:
            ProgressView("识别中…").padding()
        case .success(let result):
            VStack(spacing: 12) {
                RecognitionResultCard(result: result)
                Button {
                    prepareSave(result)
                } label: {
                    Label("保存到记录", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        case .failure(let message, let rawText):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                if let rawText, !rawText.isEmpty {
                    Text("模型原始返回：").font(.caption).foregroundStyle(.secondary)
                    Text(rawText)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var noModelHint: some View {
        VStack(spacing: 8) {
            Text("还没有可用于识别的视觉模型")
                .font(.subheadline)
            Text("请到 设置 → 模型管理 添加一个支持视觉的模型")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            image = uiImage
            vm.state = .idle
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
