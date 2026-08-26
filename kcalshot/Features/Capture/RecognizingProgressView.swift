import SwiftUI

/// 识别中的进度：竖向步骤条 —— 上传照片（准备/上传%/已上传）→ 模型分析。
struct RecognizingProgressView: View {
    let isPhoto: Bool
    let phase: RecognitionViewModel.Phase
    var samplesDone: Int = 0
    var samplesTotal: Int = 0

    private var isWaiting: Bool {
        if case .waiting = phase { return true }
        return false
    }

    private var isMultiSample: Bool { samplesTotal > 1 }

    private enum StepState { case done, active, pending }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isPhoto {
                stepRow(
                    state: isWaiting ? .done : .active,
                    title: "上传照片",
                    subtitle: uploadSubtitle,
                    connector: true,
                    fraction: uploadFraction
                )
            }
            stepRow(
                state: analyzeState,
                title: isMultiSample ? "高精度识别" : "分析食物与营养",
                subtitle: analyzeSubtitle,
                connector: false,
                fraction: nil
            )
        }
        .padding(18)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.hairline, lineWidth: 1))
    }

    private var analyzeState: StepState {
        guard isPhoto else { return .active }
        return isWaiting ? .active : .pending
    }

    private var uploadSubtitle: String {
        switch phase {
        case .preparing: return String(localized: "准备图片…")
        case .uploading(let fraction): return "\(Int(fraction * 100))%"
        case .waiting: return String(localized: "已上传")
        }
    }

    private var uploadFraction: Double? {
        if case .uploading(let fraction) = phase { return fraction }
        return nil
    }

    private var analyzeSubtitle: String {
        guard analyzeState == .active else { return String(localized: "等待图片上传完成…") }
        if isMultiSample {
            return "多次分析中 \(samplesDone)/\(samplesTotal)，将取中位数…"
        }
        return String(localized: "正在识别，分析食物与营养…")
    }

    @ViewBuilder
    private func stepRow(state: StepState, title: String, subtitle: String, connector: Bool, fraction: Double?) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                node(state)
                if connector {
                    Rectangle()
                        .fill(state == .done ? Color.brandGreen : Color.hairline)
                        .frame(width: 2, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(state == .pending ? Color.inkTertiary : Color.inkPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(state == .active ? Color.brandGreenDeep : Color.inkTertiary)
                if let fraction {
                    ProgressView(value: fraction)
                        .tint(.brandGreen)
                        .frame(width: 180)
                } else if state == .active {
                    ForwardProgressBar().frame(width: 190)
                }
            }
            .padding(.bottom, connector ? 8 : 0)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func node(_ state: StepState) -> some View {
        switch state {
        case .done:
            Circle().fill(Color.brandGreen)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
        case .active:
            Circle().fill(Color.cardSurface)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.brandGreen, lineWidth: 2))
                .overlay { Spinner() }
        case .pending:
            Circle().fill(Color.hairline).frame(width: 30, height: 30)
        }
    }
}

/// 绿色旋转指示器。
private struct Spinner: View {
    @State private var spin = false
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.72)
            .stroke(Color.brandGreen, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 15, height: 15)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spin = true }
            }
    }
}

/// 正常的从左往右填充进度条：快速推进后在末端放缓、稳住（识别完成即随视图消失）。
private struct ForwardProgressBar: View {
    @State private var progress: CGFloat = 0.04
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.brandGreen.opacity(0.15))
                Capsule().fill(Color.brandGreen)
                    .frame(width: max(6, geo.size.width * progress))
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeOut(duration: 9)) { progress = 0.92 }
        }
    }
}
