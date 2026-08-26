import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct CaptureView: View {
    enum InputMode { case photo, text }
    var mode: InputMode = .photo
    /// 新记录归属的日期（从日历某天进入时为那一天，否则为今天）。
    var targetDate: Date = .now
    /// 指定餐次；为 nil 则按时段推断。
    var targetMeal: MealType?

    init(
        mode: InputMode = .photo,
        selectedPhoto: PhotoSelection? = nil,
        targetDate: Date = .now,
        targetMeal: MealType? = nil
    ) {
        self.mode = mode
        self.targetDate = targetDate
        self.targetMeal = targetMeal
        _selectedPhoto = State(initialValue: selectedPhoto)
    }

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \APIModelConfig.displayName) private var models: [APIModelConfig]

    @State private var selectedPhoto: PhotoSelection?
    @State private var textDescription = ""
    @State private var correction = ""
    @State private var showCorrectionSheet = false
    @State private var selectedModel: APIModelConfig?
    @State private var showSourceDialog = false
    @State private var vm = RecognitionViewModel()
    @State private var draft: SaveDraft?
    @FocusState private var textFieldFocused: Bool

    private var image: UIImage? { selectedPhoto?.image }

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
                                .id("top")
                                .animation(.easeInOut(duration: 0.25), value: hasResult)
                        } else {
                            textInputArea
                        }

                        if availableModels.isEmpty {
                            noModelHint
                        } else {
                            modelPicker
                            if mode == .photo, !hasResult {
                                noteField
                            }
                            if isReRecognize {
                                recognizeButton
                            }
                            resultArea.id("result")
                        }
                    }
                    .padding()
                }
                .background(Color.appBackground)
                .onChange(of: successResult) { _, result in
                    if result != nil {
                        // 滚到顶部：缩小后的图片在上、概览紧随其后，同屏可见。
                        withAnimation { proxy.scrollTo("top", anchor: .top) }
                    }
                }
            }
            .navigationTitle(mode == .photo ? "识别食物" : "文字记录")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let result = successResult {
                    saveBar(for: result)
                } else if !availableModels.isEmpty {
                    recognizeBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                if selectedModel == nil {
                    selectedModel = availableModels.first(where: { $0.isDefault }) ?? availableModels.first
                }
            }
            .photoSourcePicker(isPresented: $showSourceDialog) { picked in
                selectedPhoto = picked
                correction = ""
                vm.state = .idle
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
            .sheet(isPresented: $showCorrectionSheet) {
                CorrectionSheet(correction: $correction) {
                    Task { await runRecognition() }
                }
            }
        }
    }

    private var successResult: RecognitionResult? {
        if case .success(let result) = vm.state { return result }
        return nil
    }

    /// 出结果后图片缩小，让小图与概览同屏可见。
    private var hasResult: Bool { successResult != nil }

    private func buildEntry(from result: RecognitionResult) -> MealEntry {
        MealEntry(
            date: targetDate,
            mealType: targetMeal ?? .suggested(),
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
        saveOriginalPhotoToAlbum()
        dismiss()
    }

    /// 份量需核对：进确认份量页。
    private func confirmSave(_ result: RecognitionResult) {
        saveOriginalPhotoToAlbum()
        draft = SaveDraft(entry: buildEntry(from: result), needsReview: result.needsReview)
    }

    /// 若设置开启，将原图保存到系统相册。
    private func saveOriginalPhotoToAlbum() {
        guard let selectedPhoto,
              selectedPhoto.source.shouldSaveOriginal(isEnabled: settings.saveOriginalPhoto) else {
            return
        }
        try? PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: selectedPhoto.image)
        }
    }

    @ViewBuilder
    private var imageArea: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: hasResult ? 120 : 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if !hasResult { changePhotoPill.padding(12) }
                    }
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.cardSurface)
                    .frame(height: 220)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.viewfinder")
                                .font(.largeTitle)
                                .foregroundStyle(Color.brandGreen)
                            Text("拍摄或从相册选择一张食物照片")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { showSourceDialog = true }
    }

    private var changePhotoPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text("更换照片")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55), in: Capsule())
    }

    /// 补充说明（可选）：作为附注一起传给识别，帮助模型更准。
    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(Color.brandGreenDeep)
                Text("补充说明")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.inkSecondary)
                Text("可选")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            TextField("例如：米饭约二两、煎蛋少油、饮料无糖", text: $correction, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...4)
        }
        .padding(14)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
    }

    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("请描述这一餐的食物与大致分量")
                .font(.subheadline).foregroundStyle(Color.inkSecondary)
            TextEditor(text: $textDescription)
                .focused($textFieldFocused)
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if textDescription.isEmpty {
                        Text("例如：早餐一根油条、一碗豆浆、一个茶叶蛋")
                            .foregroundStyle(Color.inkTertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var modelPicker: some View {
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
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.brandGreen.opacity(0.12))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.brandGreenDeep)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text("识别模型")
                        .font(.caption)
                        .foregroundStyle(Color.inkTertiary)
                    Text(selectedModel?.displayName ?? "选择模型")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.inkPrimary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(14)
            .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 出结果后放在滚动区的次要操作：换模型重新识别。
    private var recognizeButton: some View {
        Button {
            Task { await runRecognition() }
        } label: {
            HStack(spacing: 8) {
                if vm.isRecognizing { ProgressView().controlSize(.small) }
                Text("重新识别").font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.brandGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .foregroundStyle(Color.brandGreenDeep)
        }
        .buttonStyle(.plain)
        .disabled(recognizeDisabled)
        .opacity(recognizeDisabled ? 0.5 : 1)
    }

    /// 无结果时固定在底部的主操作：识别。
    private var recognizeBar: some View {
        Button {
            Task { await runRecognition() }
        } label: {
            HStack(spacing: 9) {
                if vm.isRecognizing {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(vm.isRecognizing ? "识别中…" : (mode == .photo ? "识别这一餐" : "识别"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                LinearGradient(colors: [.brandGreen, .brandGreenDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(recognizeDisabled)
        .opacity(recognizeDisabled ? 0.5 : 1)
        .shadow(color: Color.brandGreen.opacity(recognizeDisabled ? 0 : 0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
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
        textFieldFocused = false
        guard let model = selectedModel else { return }
        switch mode {
        case .photo:
            guard let image else { return }
            let note = correction.trimmingCharacters(in: .whitespacesAndNewlines)
            await vm.recognize(image: image, model: model, settings: settings, correction: note.isEmpty ? nil : note)
        case .text:
            let text = textDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            await vm.recognizeText(description: text, model: model, settings: settings)
        }
        recordTokenUsage(model: model)
    }

    /// 识别完成后记录本次 token 用量（无论是否保存这一餐）。端点未返回用量则不落库。
    private func recordTokenUsage(model: APIModelConfig) {
        guard let usage = vm.successResult?.tokenUsage else { return }
        context.insert(TokenUsage(
            modelDisplay: model.displayName,
            promptTokens: usage.prompt,
            completionTokens: usage.completion,
            totalTokens: usage.total,
            kind: mode == .photo ? .photo : .text
        ))
    }

    /// 固定在底部的保存操作栏：位置与颜色固定，不随 needsReview 变化。
    private func saveBar(for result: RecognitionResult) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                softSaveButton("补充说明重识别", systemImage: "text.bubble") {
                    showCorrectionSheet = true
                }
                softSaveButton("调整份量后保存", systemImage: "slider.horizontal.3") {
                    confirmSave(result)
                }
            }
            Button {
                directSave(result)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                    Text("直接保存").font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(
                    LinearGradient(colors: [.brandGreen, .brandGreenDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .shadow(color: Color.brandGreen.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func softSaveButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title).font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .foregroundStyle(Color.inkPrimary)
        }
        .buttonStyle(.plain)
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
            RecognizingProgressView(
                isPhoto: mode == .photo,
                phase: vm.phase,
                samplesDone: vm.samplesDone,
                samplesTotal: vm.samplesTotal
            )
        case .success(let result):
            RecognitionResultCard(result: Binding(
                get: { vm.successResult ?? result },
                set: { vm.successResult = $0 }
            ))
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
            Image(systemName: "sparkles.slash")
                .font(.title2)
                .foregroundStyle(Color.inkTertiary)
            Text("还没有可用于识别的视觉模型")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
            Text("请前往「设置 → 模型管理」添加支持视觉的模型")
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
    }
}

#Preview {
    CaptureView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
