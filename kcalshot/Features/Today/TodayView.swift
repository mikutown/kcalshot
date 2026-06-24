import SwiftUI
import SwiftData

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "今天还没有记录",
                systemImage: "fork.knife",
                description: Text("拍一张照片，开始记录你的第一餐")
            )
            .navigationTitle("今天")
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
}
