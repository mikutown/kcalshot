import SwiftUI

/// 识别中的进度：上方卡片为图片上传，上传跑完后下方卡片为模型识别。
struct RecognizingProgressView: View {
    let isPhoto: Bool
    let phase: RecognitionViewModel.Phase

    private var isWaiting: Bool {
        if case .waiting = phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 12) {
            if isPhoto {
                uploadCard
            }
            modelCard
        }
    }

    private var uploadCard: some View {
        progressCard("图片上传", systemImage: "arrow.up.circle", active: !isWaiting) {
            switch phase {
            case .preparing:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("准备图片…").font(.caption).foregroundStyle(.secondary)
                }
            case .uploading(let fraction):
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: fraction)
                    Text("\(Int(fraction * 100))%").font(.caption).foregroundStyle(.secondary)
                }
            case .waiting:
                Label("已上传", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            }
        }
    }

    private var modelCard: some View {
        progressCard("模型识别", systemImage: "sparkles", active: isWaiting) {
            if isWaiting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在识别，分析食物与营养…").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("等待图片上传完成…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func progressCard<Content: View>(
        _ title: String,
        systemImage: String,
        active: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(active ? .primary : .secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .opacity(active ? 1 : 0.6)
    }
}
