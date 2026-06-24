import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "sun.max") }
            DiaryView()
                .tabItem { Label("记录", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
