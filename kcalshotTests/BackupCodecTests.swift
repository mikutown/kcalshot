import XCTest
import SwiftData
@testable import kcalshot

final class BackupCodecTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MealEntry.self, DailyGoal.self, APIModelConfig.self,
            WeightEntry.self, WaterEntry.self, FavoriteFood.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @MainActor
    func testExportRestoreRoundTrip() throws {
        let ctx = try makeContext()
        ctx.insert(MealEntry(
            mealType: .lunch, name: "测试餐",
            items: [FoodItem(name: "米饭", grams: 150, caloriesPer100g: 130,
                             proteinPer100g: 3, fatPer100g: 1, carbsPer100g: 28)],
            healthScore: 7
        ))
        ctx.insert(WaterEntry(amountML: 250))
        ctx.insert(FavoriteFood(name: "鸡胸", defaultGrams: 120, caloriesPer100g: 120,
                                proteinPer100g: 23, fatPer100g: 2, carbsPer100g: 0,
                                healthScore: 9, healthReason: ""))
        let data = try BackupCodec.export(context: ctx, includeThumbnails: false)

        let restored = try makeContext()
        let summary = try BackupCodec.restore(from: data, into: restored, mode: .merge)

        XCTAssertEqual(summary.meals, 1)
        XCTAssertEqual(summary.waters, 1)
        XCTAssertEqual(summary.favorites, 1)

        let meals = try restored.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(meals.first?.name, "测试餐")
        XCTAssertEqual(meals.first?.items.first?.caloriesPer100g, 130)
        XCTAssertEqual(meals.first?.calories, 195) // 130 * 150/100
    }

    @MainActor
    func testMergeDedupByID() throws {
        let ctx = try makeContext()
        ctx.insert(WaterEntry(amountML: 100))
        let data = try BackupCodec.export(context: ctx, includeThumbnails: false)

        // 恢复回同一上下文：id 已存在 → 合并应跳过、零新增。
        let summary = try BackupCodec.restore(from: data, into: ctx, mode: .merge)
        XCTAssertEqual(summary.waters, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WaterEntry>()).count, 1)
    }

    @MainActor
    func testReplaceWipesAndImports() throws {
        let ctx = try makeContext()
        ctx.insert(WaterEntry(amountML: 100))
        let data = try BackupCodec.export(context: ctx, includeThumbnails: false)

        // 备份后再加一条本地数据；覆盖恢复应清空后只剩备份内容。
        ctx.insert(WaterEntry(amountML: 999))
        let summary = try BackupCodec.restore(from: data, into: ctx, mode: .replace)

        XCTAssertEqual(summary.waters, 1)
        let waters = try ctx.fetch(FetchDescriptor<WaterEntry>())
        XCTAssertEqual(waters.count, 1)
        XCTAssertEqual(waters.first?.amountML, 100)
    }

    @MainActor
    func testApiKeysNotIncludedInBackup() throws {
        // 备份不应包含任何 API key 字段（密钥只在 Keychain）。
        let ctx = try makeContext()
        ctx.insert(MealEntry(mealType: .snack, name: "x",
                             items: [FoodItem(name: "x", grams: 100, caloriesPer100g: 1,
                                              proteinPer100g: 0, fatPer100g: 0, carbsPer100g: 0)]))
        let data = try BackupCodec.export(context: ctx, includeThumbnails: false)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(text.lowercased().contains("apikey"))
        XCTAssertFalse(text.lowercased().contains("api_key"))
    }
}
