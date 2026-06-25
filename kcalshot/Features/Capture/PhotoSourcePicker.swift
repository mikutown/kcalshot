import SwiftUI
import PhotosUI

/// 与屏幕等宽的底部来源选择弹层（拍摄 / 从手机相册选择 / 取消）。
/// 选完来源后先关弹层，再在 onDismiss 里拉起相机/相册，避免 presentation 冲突；
/// 拿到图片后通过 onImagePicked 回调交还给调用方。
private struct PhotoSourcePicker: ViewModifier {
    @Binding var isPresented: Bool
    let onImagePicked: (UIImage) -> Void

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
                        onImagePicked(image)
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
        onImagePicked(image)
    }

    private var sourceSheet: some View {
        VStack(spacing: 0) {
            if CameraPicker.isAvailable {
                sourceRow("拍摄") { choose(.camera) }
                Divider().padding(.leading, 20)
            }
            sourceRow("从手机相册选择") { choose(.library) }
            Rectangle().fill(Color(.systemGroupedBackground)).frame(height: 8)
            sourceRow("取消") { isPresented = false }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .presentationDetents([.height(sheetHeight)])
        .presentationBackground(Color(.secondarySystemGroupedBackground))
    }

    private var sheetHeight: CGFloat {
        let rowHeight: CGFloat = 56
        let mainRows = CameraPicker.isAvailable ? 2 : 1
        return CGFloat(mainRows) * rowHeight + 8 + rowHeight + 8
    }

    private func sourceRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// 弹出全宽底部来源选择，选/拍到图片后通过 onImagePicked 回调。
    func photoSourcePicker(
        isPresented: Binding<Bool>,
        onImagePicked: @escaping (UIImage) -> Void
    ) -> some View {
        modifier(PhotoSourcePicker(isPresented: isPresented, onImagePicked: onImagePicked))
    }
}
