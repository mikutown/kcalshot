import SwiftUI

/// 全局设计 token（对应 opendesign 稿：活力鲜明 · 圆角卡片撞色）。
/// 颜色为浅色优先的固定值，后续如需暗色再补 asset catalog。
extension Color {
    // 品牌主色 / 撞色
    static let brandGreen     = Color(red: 34.0/255,  green: 197.0/255, blue: 94.0/255)   // #22C55E
    static let brandGreenDeep = Color(red: 22.0/255,  green: 163.0/255, blue: 74.0/255)   // #16A34A
    static let brandCoral     = Color(red: 255.0/255, green: 107.0/255, blue: 74.0/255)   // #FF6B4A
    static let brandOrange    = Color(red: 255.0/255, green: 176.0/255, blue: 32.0/255)   // #FFB020
    static let waterBlue      = Color(red: 56.0/255,  green: 189.0/255, blue: 248.0/255)  // #38BDF8

    // 宏量角色色
    static let macroProtein = brandGreen
    static let macroCarbs   = brandOrange
    static let macroFat     = brandCoral

    // 表面
    static let appBackground = Color(red: 247.0/255, green: 248.0/255, blue: 245.0/255)   // #F7F8F5
    static let cardSurface   = Color.white
    static let hairline      = Color(red: 238.0/255, green: 240.0/255, blue: 236.0/255)   // #EEF0EC

    // 文字墨色
    static let inkPrimary   = Color(red: 20.0/255, green: 24.0/255, blue: 26.0/255)       // #14181A
    static let inkSecondary = Color(red: 91.0/255, green: 101.0/255, blue: 96.0/255)      // #5B6560
    static let inkTertiary  = Color(red: 154.0/255, green: 163.0/255, blue: 157.0/255)    // #9AA39D
}

/// 白底圆角卡片（24pt 圆角 + 柔影），与稿中 .card 一致。
private struct CardBackground: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                Color.cardSurface,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 20) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
