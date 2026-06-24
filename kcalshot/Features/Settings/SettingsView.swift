import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("API & 模型") {
                    LabeledContent("全局 Base URL", value: "未配置")
                    LabeledContent("模型", value: "0 个")
                }
                Section("每日目标") {
                    LabeledContent("目标热量", value: "未设置")
                }
                Section("健康同步") {
                    LabeledContent("Apple 健康", value: "未开启")
                }
                Section("关于") {
                    LabeledContent("版本", value: "0.1.0 (M0)")
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
