import SwiftUI

/// 统一的「添加记录」入口协调器：由 RootView 持有并注入环境，
/// 中央 FAB 与各页（如「今天」空状态）共用同一套添加流程，避免重复的弹层接线。
@MainActor
@Observable
final class AddCoordinator {
    /// 中央「+」点按弹出的动作菜单。
    var showAddMenu = false
    /// 拍照/相册来源选择。
    var showPhotoSource = false
    /// 识别页（拍照或文字）。
    var showCapture = false
    var captureMode: CaptureView.InputMode = .photo
    var capturePhoto: PhotoSelection?
    /// 常吃 / 收藏快速添加。
    var showFavorites = false

    /// 添加菜单里选中的动作：先记录、等菜单弹层关闭后再执行，避免 sheet 之间的呈现竞态。
    enum PendingAction { case photo, text, favorites }
    var pendingAction: PendingAction?

    /// 从某个空餐次进入时的目标餐次；为 nil 则按时段推断。
    var targetMeal: MealType?

    func openMenu(meal: MealType? = nil) {
        targetMeal = meal
        showAddMenu = true
    }

    /// 菜单关闭后执行待办动作（在 sheet 的 onDismiss 里调用）。
    func runPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .photo: startPhoto()
        case .text: startText()
        case .favorites: openFavorites()
        }
    }

    func startPhoto() {
        capturePhoto = nil
        captureMode = .photo
        showPhotoSource = true
    }

    func startText() {
        capturePhoto = nil
        captureMode = .text
        showCapture = true
    }

    /// 拿到照片后进入识别页。
    func beginCapture(with photo: PhotoSelection) {
        capturePhoto = photo
        captureMode = .photo
        showCapture = true
    }

    func openFavorites() { showFavorites = true }
}
