import SwiftUI

/// 补充说明弹页：文本/语音输入识别更正，底部确认按钮随键盘浮动。
struct CorrectionSheet: View {
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
                    Text("请说明照片中识别有误之处，将携带原图重新识别。")
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
                    Text("按补充说明重新识别").frame(maxWidth: .infinity)
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
