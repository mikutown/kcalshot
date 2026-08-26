import SwiftUI
import PhotosUI

/// 与屏幕等宽的底部来源选择弹层（拍摄 / 从手机相册选择 / 取消）。
/// 选完来源后先关弹层，再在 onDismiss 里拉起相机/相册，避免 presentation 冲突；
/// 拿到图片后通过 onImagePicked 回调交还给调用方。
private struct PhotoSourcePicker: ViewModifier {
    @Binding var isPresented: Bool
    let onImagePicked: (PhotoSelection) -> Void

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var pendingSource: Source?

    private enum Source { case camera, library }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: handlePendingSource) { sourceSheet }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { pickedImage = $0 }.ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: showCamera) { _, isShown in
                // 等相机界面关闭后再回调，避免与 fullScreenCover 退场冲突。
                if !isShown, let image = pickedImage {
                    pickedImage = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        onImagePicked(PhotoSelection(image: image, source: .camera))
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadLibraryImage(item) }
            }
    }

    private func handlePendingSource() {
        switch pendingSource {
        case .camera: showCamera = true
        case .library: showPhotoPicker = true
        case .none: break
        }
        pendingSource = nil
    }

    private func choose(_ source: Source) {
        pendingSource = source
        isPresented = false
    }

    private func loadLibraryImage(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photoItem = nil
        onImagePicked(PhotoSelection(image: image, source: .library))
    }

    private var sourceSheet: some View {
        VStack(spacing: 10) {
            Text("选择照片来源")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 10)
                .padding(.bottom, 2)
            if CameraPicker.isAvailable {
                sourceOption(
                    icon: "camera.fill", tint: .brandCoral, iconColor: .brandCoral,
                    title: "拍摄", subtitle: "用相机拍一张食物照片"
                ) { choose(.camera) }
            }
            sourceOption(
                icon: "photo.on.rectangle", tint: .brandGreen, iconColor: .brandGreenDeep,
                title: "从相册选择", subtitle: "从手机相册选择已有照片"
            ) { choose(.library) }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.cardSurface)
    }

    private var sheetHeight: CGFloat {
        let rows = CameraPicker.isAvailable ? 2 : 1
        return 96 + CGFloat(rows) * 84
    }

    private func sourceOption(
        icon: String,
        tint: Color,
        iconColor: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.inkTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// 弹出全宽底部来源选择，选/拍到图片后通过 onImagePicked 回调。
    func photoSourcePicker(
        isPresented: Binding<Bool>,
        onImagePicked: @escaping (PhotoSelection) -> Void
    ) -> some View {
        modifier(PhotoSourcePicker(isPresented: isPresented, onImagePicked: onImagePicked))
    }
}
