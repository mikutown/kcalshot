import SwiftUI
import SwiftData

@main
struct KcalShotApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: MealEntry.self, DailyGoal.self, APIModelConfig.self
            )
        } catch {
            fatalError("无法创建 SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
