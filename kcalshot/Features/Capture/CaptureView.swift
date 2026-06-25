import SwiftUI
import SwiftData
import PhotosUI

struct CaptureView: View {
    enum InputMode { case photo, text }
    var mode: InputMode = .photo

    init(mode: InputMode = .photo, initialImage: UIImage? = nil) {
        self.mode = mode
        _image = State(initialValue: initialImage)
    }

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \APIModelConfig.displayName) private var models: [APIModelConfig]

    @State private var image: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var textDescription = ""
    @State private var selectedModel: APIModelConfig?
    @State private var showCamera = false
    @State private var showSourceDialog = false
    @State private var showPhotoPicker = false
    @State private var vm = RecognitionViewModel()
    @State private var draft: SaveDraft?

    /// 待保存草稿（Identifiable，配合 .sheet(item:) 避免空白页竞态）。
    private struct SaveDraft: Identifiable {
        let id = UUID()
        let entry: MealEntry
        let needsReview: Bool
    }

    /// 文字模式不要求视觉，照片模式要求视觉。
    private var availableModels: [APIModelConfig] {
        switch mode {
        case .photo: return models.filter { $0.supportsVision && !$0.modelId.isEmpty }
        case .text: return models.filter { !$0.modelId.isEmpty }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if mode == .photo {
                            imageArea
                        } else {
                            textInputArea
                        }

                        if availableModels.isEmpty {
                            noModelHint
                        } else {
                            modelPicker
                            recognizeButton
                            resultArea.id("result")
                        }
                    }
                    .padding()
                }
                .onChange(of: successResult) { _, result in
                    if result != nil {
                        withAnimation { proxy.scrollTo("result", anchor: .top) }
                    }
                }
            }
            .navigationTitle(mode == .photo ? "识别食物" : "文字记录")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let result = successResult {
                    saveBar(for: result)
                }
            }
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
                    selectedModel = availableModels.first(where: { $0.isDefault }) ?? availableModels.first
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { picked in
                    image = picked
                    vm.state = .idle
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .confirmationDialog("选择食物照片", isPresented: $showSourceDialog, titleVisibility: .hidden) {
                if CameraPicker.isAvailable {
                    Button("拍摄") { showCamera = true }
                }
                Button("从手机相册选择") { showPhotoPicker = true }
                Button("取消", role: .cancel) {}
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

    private var successResult: RecognitionResult? {
        if case .success(let result) = vm.state { return result }
        return nil
    }

    private func buildEntry(from result: RecognitionResult) -> MealEntry {
        MealEntry(
            date: .now,
            mealType: .suggested(),
            name: result.items.map(\.name).joined(separator: "、"),
            items: result.items,
            healthScore: result.healthScore,
            healthReason: result.reason,
            note: "",
            thumbnailData: image.flatMap { ImageEncoder.thumbnailData(from: $0) },
            modelUsed: result.modelUsed
        )
    }

    /// 份量无误：直接建记录并关闭，不进确认页。
    private func directSave(_ result: RecognitionResult) {
        context.insert(buildEntry(from: result))
        dismiss()
    }

    /// 份量需核对：进确认份量页。
    private func confirmSave(_ result: RecognitionResult) {
        draft = SaveDraft(entry: buildEntry(from: result), needsReview: result.needsReview)
    }

    @ViewBuilder
    private var imageArea: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .frame(maxWidth: .infinity)
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
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { showSourceDialog = true }
    }

    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("描述这一餐吃了什么、大概多少")
                .font(.subheadline).foregroundStyle(.secondary)
            TextEditor(text: $textDescription)
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if textDescription.isEmpty {
                        Text("例如：早餐吃了一根油条、一碗豆浆、一个茶叶蛋")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var modelPicker: some View {
        HStack {
            Text("识别模型").foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(availableModels) { model in
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
            Task { await runRecognition() }
        } label: {
            HStack {
                if vm.isRecognizing { ProgressView().controlSize(.small) }
                Text(isReRecognize ? "换模型重新识别" : "识别")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(recognizeDisabled)
    }

    private var recognizeDisabled: Bool {
        if vm.isRecognizing || selectedModel == nil { return true }
        switch mode {
        case .photo:
            return image == nil
        case .text:
            return textDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func runRecognition() async {
        guard let model = selectedModel else { return }
        switch mode {
        case .photo:
            guard let image else { return }
            await vm.recognize(image: image, model: model, settings: settings)
        case .text:
            let text = textDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            await vm.recognizeText(description: text, model: model, settings: settings)
        }
    }

    /// 固定在底部的保存操作栏；按 needsReview 自适应主次。
    private func saveBar(for result: RecognitionResult) -> some View {
        VStack(spacing: 8) {
            if result.needsReview {
                confirmButton(result, prominent: true)
                directButton(result, prominent: false)
            } else {
                directButton(result, prominent: true)
                confirmButton(result, prominent: false)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private func directButton(_ result: RecognitionResult, prominent: Bool) -> some View {
        let label = Label("份量无误，直接保存", systemImage: "tray.and.arrow.down")
            .frame(maxWidth: .infinity)
        if prominent {
            Button { directSave(result) } label: { label }.buttonStyle(.borderedProminent)
        } else {
            Button { directSave(result) } label: { label }.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func confirmButton(_ result: RecognitionResult, prominent: Bool) -> some View {
        let label = Label("核对份量后保存", systemImage: "checklist")
            .frame(maxWidth: .infinity)
        if prominent {
            Button { confirmSave(result) } label: { label }.buttonStyle(.borderedProminent)
        } else {
            Button { confirmSave(result) } label: { label }.buttonStyle(.bordered)
        }
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
            RecognitionResultCard(result: result)
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
