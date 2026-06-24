import SwiftUI

struct APISettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextField("Base URL", text: $settings.globalBaseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("API Key", text: $settings.globalAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("全局 Endpoint")
            } footer: {
                Text("OpenAI 兼容格式，例如 https://api.openai.com/v1 。Key 安全保存在系统钥匙串（Keychain）。各模型可在模型设置里单独覆盖。")
            }

            Section {
                ConnectionTestButton {
                    (settings.globalBaseURL, settings.globalAPIKey)
                }
            }
        }
        .navigationTitle("API 设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        APISettingsView()
    }
    .environment(PreviewData.settings)
}
