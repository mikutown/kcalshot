import SwiftUI
import SwiftData

@main
struct KcalShotApp: App {
    let modelContainer: ModelContainer
    @State private var settings = AppSettings()

    init() {
        do {
            modelContainer = try ModelContainer(
                for: MealEntry.self, DailyGoal.self, APIModelConfig.self, WeightEntry.self,
                WaterEntry.self, FavoriteFood.self, TokenUsage.self
            )
        } catch {
            fatalError("无法创建 SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
        }
        .modelContainer(modelContainer)
    }
}
