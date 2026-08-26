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
                        .font(.subheadline).foregroundStyle(Color.inkSecondary)
                    TextField("例如：饮品是牛奶不是豆浆", text: $correction, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...10)
                        .focused($focused)
                        .padding(14)
                        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
                    if speech.isRecording {
                        Label("正在聆听…", systemImage: "waveform")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.brandCoral)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("补充说明")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.brandGreen)
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
                            .foregroundStyle(speech.isRecording ? Color.brandCoral : Color.brandGreenDeep)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    speech.stop()
                    onConfirm()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("按补充说明重新识别").font(.headline)
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
                .disabled(isEmpty)
                .opacity(isEmpty ? 0.5 : 1)
                .shadow(color: Color.brandGreen.opacity(isEmpty ? 0 : 0.3), radius: 8, x: 0, y: 4)
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
