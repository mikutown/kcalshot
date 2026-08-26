import SwiftUI

/// 中央「+」弹出的自定义「添加记录」底部弹层（撞色图标磁贴列表）。
/// 选项只登记 pendingAction 并关闭本弹层，真正的跳转在 RootView 的 onDismiss 里执行。
struct AddMenuSheet: View {
    let coordinator: AddCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 10) {
            Text("添加记录")
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 8)
                .padding(.bottom, 2)

            option(
                icon: "camera.fill", tint: .brandCoral, iconColor: .brandCoral,
                title: "拍照识别", subtitle: "拍一张或从相册选，AI 识别热量与营养"
            ) { pick(.photo) }

            option(
                icon: "square.and.pencil", tint: .brandGreen, iconColor: .brandGreenDeep,
                title: "文字记录", subtitle: "用一句话描述这一餐"
            ) { pick(.text) }

            option(
                icon: "star.fill", tint: .brandOrange, iconColor: Color(red: 180.0/255, green: 118.0/255, blue: 0),
                title: "常吃 / 收藏", subtitle: "从常吃食物一键添加"
            ) { pick(.favorites) }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(324)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.cardSurface)
    }

    private func pick(_ action: AddCoordinator.PendingAction) {
        coordinator.pendingAction = action
        dismiss()
    }

    private func option(
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
                        .minimumScaleFactor(0.8)
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
