import SwiftUI
import SwiftData

struct DiaryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "暂无历史记录",
                systemImage: "calendar",
                description: Text("保存的三餐会按日期出现在这里")
            )
            .navigationTitle("记录")
        }
    }
}

#Preview {
    DiaryView()
        .modelContainer(PreviewData.container)
}
