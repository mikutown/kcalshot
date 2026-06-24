import SwiftUI
import SwiftData

struct TodayView: View {
    @State private var showCapture = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("今天还没有记录", systemImage: "fork.knife")
            } description: {
                Text("拍一张照片，开始记录你的第一餐")
            } actions: {
                Button {
                    showCapture = true
                } label: {
                    Label("拍照识别", systemImage: "camera.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("今天")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCapture = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView()
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
        .environment(PreviewData.settings)
}
