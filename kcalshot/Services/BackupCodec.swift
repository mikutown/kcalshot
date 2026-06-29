import Foundation
import SwiftData

/// 恢复方式。
enum RestoreMode {
    /// 合并：仅插入本地不存在（按 id）的记录。
    case merge
    /// 覆盖：清空同类数据后整体导入。
    case replace
}

struct RestoreSummary {
    var meals = 0
    var weights = 0
    var waters = 0
    var favorites = 0
    var tokens = 0
    var goalRestored = false
}

/// 全量数据的 JSON 备份与恢复。@Model 不直接 Codable，故用 DTO 中转。
enum BackupCodec {
    struct Backup: Codable {
        var schemaVersion: Int
        var exportedAt: Date
        var meals: [MealDTO]
        var goals: [GoalDTO]
        var weights: [WeightDTO]
        var waters: [WaterDTO]
        var favorites: [FavoriteDTO]
        var tokens: [TokenDTO]?
    }

    struct MealDTO: Codable {
        var id: UUID
        var date: Date
        var mealType: String
        var name: String
        var items: [FoodItem]
        var healthScore: Int
        var healthReason: String
        var note: String
        var modelUsed: String
        var thumbnailBase64: String?
    }

    struct GoalDTO: Codable {
        var targetCalories: Double
        var protein: Double
        var fat: Double
        var carbs: Double
        var sex: String
        var age: Int
        var heightCm: Double
        var weightKg: Double
        var activity: String
        var goalType: String
        var calorieDelta: Double
    }

    struct WeightDTO: Codable {
        var id: UUID
        var date: Date
        var weightKg: Double
    }

    struct WaterDTO: Codable {
        var id: UUID
        var date: Date
        var amountML: Double
    }

    struct FavoriteDTO: Codable {
        var id: UUID
        var name: String
        var defaultGrams: Double
        var caloriesPer100g: Double
        var proteinPer100g: Double
        var fatPer100g: Double
        var carbsPer100g: Double
        var healthScore: Int
        var healthReason: String
        var createdAt: Date
    }

    struct TokenDTO: Codable {
        var id: UUID
        var date: Date
        var modelDisplay: String
        var promptTokens: Int
        var completionTokens: Int
        var totalTokens: Int
        var kind: String
    }

    // MARK: - 导出

    static func export(context: ModelContext, includeThumbnails: Bool) throws -> Data {
        try encode(makeBackup(context: context, includeThumbnails: includeThumbnails))
    }

    /// 从 SwiftData 取数并映射为可 Sendable 的 DTO 快照。必须在 context 所在线程（主线程）调用。
    private static func makeBackup(context: ModelContext, includeThumbnails: Bool) -> Backup {
        let meals = (try? context.fetch(FetchDescriptor<MealEntry>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<DailyGoal>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        let waters = (try? context.fetch(FetchDescriptor<WaterEntry>())) ?? []
        let favorites = (try? context.fetch(FetchDescriptor<FavoriteFood>())) ?? []
        let tokens = (try? context.fetch(FetchDescriptor<TokenUsage>())) ?? []

        let backup = Backup(
            schemaVersion: 1,
            exportedAt: .now,
            meals: meals.map {
                MealDTO(
                    id: $0.id, date: $0.date, mealType: $0.mealTypeRaw, name: $0.name,
                    items: $0.items, healthScore: $0.healthScore, healthReason: $0.healthReason,
                    note: $0.note, modelUsed: $0.modelUsed,
                    thumbnailBase64: includeThumbnails ? $0.thumbnailData?.base64EncodedString() : nil
                )
            },
            goals: goals.map {
                GoalDTO(
                    targetCalories: $0.targetCalories, protein: $0.protein, fat: $0.fat, carbs: $0.carbs,
                    sex: $0.sexRaw, age: $0.age, heightCm: $0.heightCm, weightKg: $0.weightKg,
                    activity: $0.activityRaw, goalType: $0.goalTypeRaw, calorieDelta: $0.calorieDelta
                )
            },
            weights: weights.map { WeightDTO(id: $0.id, date: $0.date, weightKg: $0.weightKg) },
            waters: waters.map { WaterDTO(id: $0.id, date: $0.date, amountML: $0.amountML) },
            favorites: favorites.map {
                FavoriteDTO(
                    id: $0.id, name: $0.name, defaultGrams: $0.defaultGrams,
                    caloriesPer100g: $0.caloriesPer100g, proteinPer100g: $0.proteinPer100g,
                    fatPer100g: $0.fatPer100g, carbsPer100g: $0.carbsPer100g,
                    healthScore: $0.healthScore, healthReason: $0.healthReason, createdAt: $0.createdAt
                )
            },
            tokens: tokens.map {
                TokenDTO(
                    id: $0.id, date: $0.date, modelDisplay: $0.modelDisplay,
                    promptTokens: $0.promptTokens, completionTokens: $0.completionTokens,
                    totalTokens: $0.totalTokens, kind: $0.kindRaw
                )
            }
        )

        return backup
    }

    private static func encode(_ backup: Backup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func exportFile(context: ModelContext, includeThumbnails: Bool) async throws -> URL {
        // 取数在主线程（绑定 context），编码与写盘是 CPU/IO 密集，放到后台线程避免卡顿。
        let backup = makeBackup(context: context, includeThumbnails: includeThumbnails)
        return try await Task.detached(priority: .utility) {
            let data = try encode(backup)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("kcalshot-backup.json")
            try data.write(to: url)
            return url
        }.value
    }

    // MARK: - 恢复

    static func restore(from data: Data, into context: ModelContext, mode: RestoreMode) throws -> RestoreSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: data)

        if mode == .replace {
            try deleteAll(MealEntry.self, in: context)
            try deleteAll(WeightEntry.self, in: context)
            try deleteAll(WaterEntry.self, in: context)
            try deleteAll(FavoriteFood.self, in: context)
            try deleteAll(TokenUsage.self, in: context)
            try deleteAll(DailyGoal.self, in: context)
        }

        var summary = RestoreSummary()

        let existingMeals = mode == .merge ? Set(((try? context.fetch(FetchDescriptor<MealEntry>())) ?? []).map(\.id)) : []
        for dto in backup.meals where !existingMeals.contains(dto.id) {
            let entry = MealEntry(
                date: dto.date,
                mealType: MealType(rawValue: dto.mealType) ?? .snack,
                name: dto.name,
                items: dto.items,
                healthScore: dto.healthScore,
                healthReason: dto.healthReason,
                note: dto.note,
                thumbnailData: dto.thumbnailBase64.flatMap { Data(base64Encoded: $0) },
                modelUsed: dto.modelUsed
            )
            entry.id = dto.id
            context.insert(entry)
            summary.meals += 1
        }

        let existingWeights = mode == .merge ? Set(((try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []).map(\.id)) : []
        for dto in backup.weights where !existingWeights.contains(dto.id) {
            let e = WeightEntry(date: dto.date, weightKg: dto.weightKg)
            e.id = dto.id
            context.insert(e)
            summary.weights += 1
        }

        let existingWaters = mode == .merge ? Set(((try? context.fetch(FetchDescriptor<WaterEntry>())) ?? []).map(\.id)) : []
        for dto in backup.waters where !existingWaters.contains(dto.id) {
            let e = WaterEntry(date: dto.date, amountML: dto.amountML)
            e.id = dto.id
            context.insert(e)
            summary.waters += 1
        }

        let existingFavs = mode == .merge ? Set(((try? context.fetch(FetchDescriptor<FavoriteFood>())) ?? []).map(\.id)) : []
        for dto in backup.favorites where !existingFavs.contains(dto.id) {
            let f = FavoriteFood(
                name: dto.name, defaultGrams: dto.defaultGrams,
                caloriesPer100g: dto.caloriesPer100g, proteinPer100g: dto.proteinPer100g,
                fatPer100g: dto.fatPer100g, carbsPer100g: dto.carbsPer100g,
                healthScore: dto.healthScore, healthReason: dto.healthReason, createdAt: dto.createdAt
            )
            f.id = dto.id
            context.insert(f)
            summary.favorites += 1
        }

        let existingTokens = mode == .merge ? Set(((try? context.fetch(FetchDescriptor<TokenUsage>())) ?? []).map(\.id)) : []
        for dto in (backup.tokens ?? []) where !existingTokens.contains(dto.id) {
            let t = TokenUsage(
                date: dto.date, modelDisplay: dto.modelDisplay,
                promptTokens: dto.promptTokens, completionTokens: dto.completionTokens,
                totalTokens: dto.totalTokens,
                kind: RecognitionKind(rawValue: dto.kind) ?? .photo
            )
            t.id = dto.id
            context.insert(t)
            summary.tokens += 1
        }

        // 目标：合并时仅当本地无目标才导入；覆盖时已清空，直接导入第一条。
        let hasGoal = ((try? context.fetch(FetchDescriptor<DailyGoal>())) ?? []).isEmpty == false
        if let g = backup.goals.first, !(mode == .merge && hasGoal) {
            let goal = DailyGoal(
                targetCalories: g.targetCalories, protein: g.protein, fat: g.fat, carbs: g.carbs,
                sex: BiologicalSex(rawValue: g.sex) ?? .male, age: g.age,
                heightCm: g.heightCm, weightKg: g.weightKg,
                activityLevel: ActivityLevel(rawValue: g.activity) ?? .sedentary,
                goalType: GoalType(rawValue: g.goalType) ?? .maintain,
                calorieDelta: g.calorieDelta
            )
            context.insert(goal)
            summary.goalRestored = true
        }

        return summary
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for item in all { context.delete(item) }
    }
}
