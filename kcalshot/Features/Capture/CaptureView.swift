import SwiftUI
import SwiftData
import PhotosUI

struct CaptureView: View {
    enum InputMode { case photo, text }
    var mode: InputMode = .photo
    /// 新记录归属的日期（从日历某天进入时为那一天，否则为今天）。
    var targetDate: Date = .now

    init(mode: InputMode = .photo, initialImage: UIImage? = nil, targetDate: Date = .now) {
        self.mode = mode
        self.targetDate = targetDate
        _image = State(initialValue: initialImage)
    }

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \APIModelConfig.displayName) private var models: [APIModelConfig]

    @State private var image: UIImage?
    @State private var textDescription = ""
    @State private var correction = ""
    @State private var showCorrectionSheet = false
    @State private var selectedModel: APIModelConfig?
    @State private var showSourceDialog = false
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
                                .id("top")
                                .animation(.easeInOut(duration: 0.25), value: hasResult)
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
                image = picked
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
                    .frame(maxHeight: hasResult ? 120 : 300)
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
            let note = correction.trimmingCharacters(in: .whitespacesAndNewlines)
            await vm.recognize(image: image, model: model, settings: settings, correction: note.isEmpty ? nil : note)
        case .text:
            let text = textDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            await vm.recognizeText(description: text, model: model, settings: settings)
        }
    }

    /// 固定在底部的保存操作栏：位置与颜色固定，不随 needsReview 变化。
    private func saveBar(for result: RecognitionResult) -> some View {
        VStack(spacing: 8) {
            Button {
                showCorrectionSheet = true
            } label: {
                Label("需要补充", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                confirmSave(result)
            } label: {
                Label("需要修改食物分量", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                directSave(result)
            } label: {
                Label("直接保存", systemImage: "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
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
}

/// 补充说明弹页：文本/语音输入识别更正，底部确认按钮随键盘浮动。
private struct CorrectionSheet: View {
    @Binding var correction: String
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var speech = SpeechRecognizer()
    @State private var base = ""
    @FocusState private var focused: Bool

    private var isEmpty: Bool {
        correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("告诉模型这张图里哪里识别错了，会带原图重新识别。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    TextField("例如：饮品是牛奶不是豆浆", text: $correction, axis: .vertical)
                        .lineLimit(3...10)
                        .focused($focused)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    if speech.isRecording {
                        Label("正在聆听…", systemImage: "waveform")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("补充说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { speech.stop(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !isEmpty {
                        Button("清空") { correction = ""; base = "" }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleRecording()
                    } label: {
                        Label(speech.isRecording ? "停止" : "口述",
                              systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            .foregroundStyle(speech.isRecording ? .red : Color.accentColor)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    speech.stop()
                    onConfirm()
                    dismiss()
                } label: {
                    Text("按修正重新识别").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isEmpty)
                .padding()
                .background(.bar)
            }
            .onChange(of: speech.transcript) { _, text in
                correction = base.isEmpty ? text : base + " " + text
            }
            .onAppear { focused = true }
            .onDisappear { speech.stop() }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleRecording() {
        if speech.isRecording {
            speech.stop()
        } else {
            Task {
                guard await speech.requestAuthorization() else { return }
                base = correction.trimmingCharacters(in: .whitespacesAndNewlines)
                speech.start()
            }
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
