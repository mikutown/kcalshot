import Foundation
import SwiftData

/// 仅供 SwiftUI 预览使用的内存 ModelContainer 与设置。
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(
                for: MealEntry.self, DailyGoal.self, APIModelConfig.self,
                configurations: config
            )
        } catch {
            fatalError("无法创建预览 ModelContainer: \(error)")
        }
    }()

    static let settings = AppSettings()
}
