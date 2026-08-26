import SwiftUI

struct RootView: View {
    @State private var addCoordinator = AddCoordinator()
    @State private var selection = 0
    /// 中央占位槽的 tag：点它等同点 FAB（打开添加菜单），并回到上一个真实 tab。
    private static let fabSlotTag = 2

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tag(0)
                .tabItem { Label("今天", systemImage: "sun.max") }
            DiaryView()
                .tag(1)
                .tabItem { Label("记录", systemImage: "calendar") }
            // 中央占位空槽：让 tab bar 变 5 等分，FAB 居中不挤两侧。
            Color.clear
                .tag(Self.fabSlotTag)
                .tabItem { Text(" ") }
            InsightsView()
                .tag(3)
                .tabItem { Label("统计", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tag(4)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .onChange(of: selection) { previous, current in
            guard current == Self.fabSlotTag else { return }
            // 点到占位槽：退回上一个真实 tab，并弹出添加菜单。
            selection = previous == Self.fabSlotTag ? 0 : previous
            addCoordinator.openMenu()
        }
        .tint(.brandGreen)
        .environment(addCoordinator)
        .overlay(alignment: .bottom) { centerFAB }
        // 添加动作菜单（中央「+」点按）：自定义撞色磁贴弹层。
        .sheet(isPresented: $addCoordinator.showAddMenu, onDismiss: { addCoordinator.runPendingAction() }) {
            AddMenuSheet(coordinator: addCoordinator)
        }
        // 拍照/相册来源选择。
        .photoSourcePicker(isPresented: $addCoordinator.showPhotoSource) { photo in
            addCoordinator.beginCapture(with: photo)
        }
        .sheet(isPresented: $addCoordinator.showCapture) {
            CaptureView(
                mode: addCoordinator.captureMode,
                selectedPhoto: addCoordinator.capturePhoto,
                targetMeal: addCoordinator.targetMeal
            )
        }
        .sheet(isPresented: $addCoordinator.showFavorites) {
            QuickAddView(targetMeal: addCoordinator.targetMeal)
        }
    }

    /// 底部中央凸起的「+」：点按弹出添加菜单，长按直达常吃/收藏。
    private var centerFAB: some View {
        Button {
            addCoordinator.openMenu()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(
                        colors: [.brandCoral, .brandOrange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 21, style: .continuous)
                )
                .shadow(color: Color.brandCoral.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .offset(y: -6)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                addCoordinator.targetMeal = nil
                addCoordinator.openFavorites()
            }
        )
        .accessibilityLabel("添加记录")
        .accessibilityHint("长按可直接打开常吃收藏")
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
