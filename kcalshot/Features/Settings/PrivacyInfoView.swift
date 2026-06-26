import SwiftUI

struct PrivacyInfoView: View {
    var body: some View {
        List {
            Section {
                Text("KcalShot 自身没有服务器，不收集、不分析、不转发你的任何数据。App 用的是你自己配置的 LLM API。")
            }

            Section("数据存在哪里") {
                row("食物照片", "不长期保存原图；识别用的压缩图仅临时使用")
                row("缩略图 / 三餐记录 / 目标", "仅存本机（App 沙盒）")
                row("API Key", "存系统钥匙串（Keychain），不明文落盘")
                row("每日热量", "本机；开启后可写入 Apple 健康")
                row("活动消耗", "开启健康后从 Apple 健康读取，仅用于计算当日预算")
                row("体重", "本机记录；开启健康后也读取 Apple 健康里的体重用于趋势")
            }

            Section("会上传什么") {
                Text("只有识别时，图片或文字会发送到你配置的 API endpoint。除此之外，App 不向任何地方发送数据。")
            }

            Section {
                Text("如果你的 endpoint 是第三方服务（OpenAI / 中转站 / 代理），图片会离开本机并按该服务的条款处理——这部分的信任与责任在于你对 endpoint 的选择。")
            } header: {
                Text("责任边界")
            } footer: {
                Text("如果要做到「绝不外流」，请把 endpoint 配成本地模型（如 Ollama）。")
            }
        }
        .navigationTitle("数据与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { PrivacyInfoView() }
}
