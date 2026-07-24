# KcalShot 技术架构文档

> 版本：v0.5 · 最后更新：2026-07-24

---

## 目录

1. [架构概览](#1-架构概览)
2. [技术选型](#2-技术选型)
3. [数据层（SwiftData）](#3-数据层swiftdata)
4. [服务层](#4-服务层)
5. [UI 层（Features）](#5-ui-层features)
6. [数据流详解](#6-数据流详解)
7. [安全与隐私设计](#7-安全与隐私设计)
8. [国际化方案](#8-国际化方案)
9. [测试策略](#9-测试策略)

---

## 1. 架构概览

KcalShot 采用 **MVVM** 架构模式，整体分为三层：

```
┌─────────────────────────────────────┐
│          UI Layer (Features)         │
│   SwiftUI Views + @Observable VMs    │
├─────────────────────────────────────┤
│        Service Layer (Services)       │
│   LLMClient · HealthKit · Keychain   │
├─────────────────────────────────────┤
│        Data Layer (Models)           │
│   SwiftData @Model · AppSettings     │
└─────────────────────────────────────┘
```

**分层原则：**
- **Data Layer**：纯数据模型，不依赖 UI
- **Service Layer**：无状态服务，通过 async/await 暴露接口
- **UI Layer**：View 只做布局，ViewModel 处理业务逻辑与状态管理

**不引入外部依赖**：整个 App 零第三方库，全部基于 Apple 原生框架（SwiftUI、SwiftData、HealthKit、Keychain Services）。

---

## 2. 技术选型

| 组件 | 选型 | 理由 |
|------|------|------|
| UI 框架 | SwiftUI | 声明式、与 SwiftData 深度集成 |
| 数据持久化 | SwiftData | iOS 17+ 原生 ORM，零配置 |
| 架构模式 | MVVM | SwiftUI 官方推荐模式 |
| 网络请求 | URLSession + async/await | 原生，轻量 |
| 密钥存储 | Keychain Services | 系统级安全存储 |
| 非敏感设置 | UserDefaults (`@Observable` + `UserDefaults`) | 简单键值存储 |
| 健康数据 | HealthKit | Apple 健康平台 |
| 语音识别 | Speech Framework | 原生语音转文字 |
| 图片压缩 | ImageIO + Core Graphics | 原生图片处理 |
| 图标生成 | Swift 脚本 (`tools/makeicon.swift`) | 自动化构建 |

### 为什么零第三方依赖？

- 项目功能边界明确，Apple 原生 API 均能覆盖
- 避免 SPM/CocoaPods 的依赖管理与兼容性问题
- 降低 App 体积，提升启动速度
- 隐私优先：无第三方 SDK 意味着无隐式数据上报

---

## 3. 数据层（SwiftData）

### 3.1 Model Container

所有模型在 `kcalshotApp.swift` 中统一注册到 `ModelContainer`：

```swift
let container = try ModelContainer(
    for: MealEntry.self, DailyGoal.self, APIModelConfig.self,
        WeightEntry.self, WaterEntry.self, FavoriteFood.self,
        TokenUsage.self
)
```

默认为**自动迁移**（`automatic` 模式）。

### 3.2 模型关系图

```
MealEntry ──has many──▶ FoodItem
    │                        │
    │                        └── has many──▶ FoodAlternative
    │
    ├── belongs to──▶ DailyGoal (通过日期匹配)
    └── uses──▶ APIModelConfig (识别模型引用)

DailyGoal: 单例（实际每次修改创建新版本）
APIModelConfig: 多记录，isDefault 标记默认
WeightEntry: 按日期排序的时间序列
WaterEntry: 按日期排序的时间序列
FavoriteFood: 从已保存的 FoodItem 创建
TokenUsage: 每次识别的 token 消耗记录
```

### 3.3 核心模型详解

#### MealEntry（三餐记录）

```swift
@Model
class MealEntry {
    var id: UUID
    var date: Date           // 记录日期
    var mealType: String     // breakfast / lunch / dinner / snack
    var name: String         // 用户可自定义名称
    var items: [FoodItem]    // 食物项列表
    var healthScore: Int     // 1-10 综合健康评分
    var healthReason: String // 评分理由
    var note: String         // 用户备注
    @Attribute(.externalStorage)
    var thumbnailData: Data? // 缩略图（外部存储）
    var modelUsed: String    // 识别所用模型名
}
```

#### FoodItem（食物项）

营养数据以 **每 100g 密度** 存储，实际营养值 = `grams * (per100gValue / 100)`。

```swift
@Model
class FoodItem {
    var id: UUID
    var name: String
    var grams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbsPer100g: Double
    var healthScore: Int
    var healthReason: String
    var alternatives: [FoodAlternative]  // 模型返回的备选食物
}
```

**设计决策**：使用密度而非绝对值的优势——用户调整份量时只需改 `grams`，无需重算营养值。

#### DailyGoal（每日目标）

```swift
@Model
class DailyGoal {
    var targetCalories: Double
    var protein: Double    // gram target
    var fat: Double
    var carbs: Double
    var sex: String        // male / female
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityLevel: String // sedentary / light / moderate / active / veryActive
    var goalType: String   // lose / maintain / gain
    
    // Computed
    var tdee: Double { get }
    func recompute()       // 根据 Mifflin-St Jeor 重算目标
}
```

#### APIModelConfig（LLM 模型配置）

支持为每个模型独立配置 baseURL 和 API Key（覆盖全局默认值）：

```swift
@Model
class APIModelConfig {
    var displayName: String
    var modelId: String          // 模型 ID（如 gpt-4o）
    var supportsVision: Bool     // 是否支持视觉
    var isDefault: Bool
    var overrideBaseURL: String? // 可空，继承全局
    // 对应 Keychain key: "model_key_<id>"
}
```

### 3.4 全局设置（非 SwiftData）

`AppSettings` 是一个 `@Observable` 类，通过 `UserDefaults` 持久化，管理：

- `globalBaseURL` / `globalKey`（key 通过 Keychain 存取）
- `uiLanguage`（system / zh-Hans / en）
- `waterGoalML` / `weightUnit` 等用户偏好
- `healthKitEnabled` 等开关

---

## 4. 服务层

### 4.1 LLMClient（AI 识别核心）

```
┌──────────────────────────────────────────┐
│              LLMClient                    │
│                                          │
│  + recognize(model:, imageData:, lang:)  │
│         │                                │
│         ▼                                │
│  1. 图片压缩 & base64 编码               │
│  2. 构造 system/user prompt              │
│  3. POST {base_url}/chat/completions     │
│  4. 解析 JSON → RecognitionResult       │
│  5. 应用 needsReview 启发式              │
└──────────────────────────────────────────┘
```

**请求格式：**

```
POST {base_url}/chat/completions
Content-Type: application/json
Authorization: Bearer {api_key}

{
  "model": "{modelId}",
  "messages": [
    {"role": "system", "content": "{系统提示}"},
    {"role": "user", "content": [
      {"type": "text", "text": "{用户指令}"},
      {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
    ]}
  ],
  "stream": false,
  "temperature": 0.1
}
```

**输出格式约束：** 通过 system prompt 指定严格 JSON 格式（`RecognitionPrompt.swift`）。

**JSON 解析失败处理：** 重试 1 次 → 仍失败则保留原始文本供手动录入。

### 4.2 RecognitionAggregator（高精度聚合）

多采样模式（默认关闭，用户可选）：

- 对同一图片并行发起 3 或 5 次调用
- 对每项营养值取 **中位数**（抗异常值）
- 由用户选择启用

### 4.3 图片处理管线（ImageEncoder）

```
原始图片 ──▶ 下采样（长边 ≤1024px）
           ▶ JPEG 压缩（quality 0.8）
           ▶ Base64 编码
           ▶ 构造 data URI (data:image/jpeg;base64,...)
```

### 4.4 HealthKitManager

- **写入**：当日摄入总热量（Dietary Energy）、可选写入体重
- **读取**（可选）：当日活动消耗（Active Energy）
- **策略**：删除旧值后写入新值，保证写入最新的当日总计
- **权限**：请求最小必要权限，授权失败优雅降级

### 4.5 KeychainStore

轻量 Keychain 封装，按 service + account 存取：

```swift
- store(key:secret:) → 增/改
- retrieve(key:) → 读取
- delete(key:) → 删除
```

存储项：
- `global_api_key`：全局 API Key
- `model_key_<modelID>`：各模型覆盖 key

### 4.6 BackupCodec（备份/恢复）

由于 SwiftData `@Model` 不直接遵循 `Codable`，设计 DTO 层完成序列化：

- **导出**：从 SwiftData 读取 → 映射为 DTO → JSON
- **导入**：从 JSON 解析 DTO → 写入 SwiftData
- **恢复模式**：
  - `merge`：现有记录 + 导入记录去重合并
  - `replace`：清空现有数据后导入

覆盖模型：MealEntry、DailyGoal、APIModelConfig、WeightEntry、WaterEntry、FavoriteFood、TokenUsage

### 4.7 CSVExporter

导出为 CSV 格式，覆盖：
- 三餐记录（日期/餐次/食物/热量/各营养素/评分）
- 体重记录
- 喝水记录
- Token 用量

---

## 5. UI 层（Features）

### 5.1 标签页结构

```
RootView
├── Tab 0: TodayView     (今天 / sun.max)
│   ├── 每日进度总览（热量环形图）
│   ├── 喝水卡片（WaterCard）
│   ├── 三餐列表（按餐次分组）
│   └── 拍照/FAB 按钮
├── Tab 1: DiaryView     (记录 / calendar)
│   ├── 月份日历网格
│   │   └── 每日圆点（颜色表示摄入达标状态）
│   └── 日期详情页（DayDetailView）
│       └── 餐食列表 + 新增入口
├── Tab 2: InsightsView  (统计 / chart.bar.xaxis)
│   ├── 摄入趋势柱状图
│   ├── 体重趋势折线图
│   └── 统计摘要（日均摄入/达标天数/连续达标天数）
└── Tab 3: SettingsView  (设置 / gearshape)
    ├── API 设置（全局 URL + Key）
    ├── 模型列表（增删改 + 默认选择）
    ├── 每日目标（TDEE 计算器）
    ├── 体重记录
    ├── 喝水目标
    ├── Token 用量
    ├── 数据管理（CSV 导出 + JSON 备份恢复）
    ├── 语言切换
    └── 隐私说明
```

### 5.2 Capture 流程

```
TodayView ──▶ PhotoSourcePicker (相机/相册)
                │
                ▼
          CaptureView
                │
                ├── idle: 显示取景/预览
                ├── recognizing: 显示进度动画 (RecognizingProgressView)
                ├── success: 显示结果卡片 (RecognitionResultCard)
                │       ├── 正常 → 一键保存
                │       └── needsReview → 高亮提示，默认展开编辑
                ├── 用户可切换模型 → 重识别
                └── failure: 显示错误 + 重试
```

### 5.3 ViewModel 状态管理

`RecognitionViewModel` 使用 `@Observable` 管理识别状态机：

```swift
@Observable
class RecognitionViewModel {
    enum State {
        case idle
        case recognizing(progress: Double)
        case success(RecognitionResult)
        case failure(Error)
    }
    
    var state: State = .idle
    var selectedModelId: String
    var imageData: Data?
    var resultAlternatives: [RecognitionResult]
    
    func startRecognition()
    func retryWithModel(_ modelId: String)
    func saveResult(as mealType: String) async throws
}
```

---

## 6. 数据流详解

### 6.1 核心识别流程

```
用户拍照
    │
    ▼
ImageEncoder.compress() ──▶ JPEG + base64
    │
    ▼
LLMClient.recognize() ──▶ POST /chat/completions
    │
    ▼
JSON 解析 ──▶ RecognitionResult
    │
    ▼
needsReview 启发式计算
    │
    ▼
RecognitionViewModel.state = .success(result)
    │
    ▼
用户确认/修改 → MealEntry.save() → SwiftData
```

### 6.2 每日统计计算

```
TodayView.onAppear
    │
    ▼
FetchDescriptor<MealEntry>(date == today)
    │
    ▼
NutritionTotals.aggregate(entries)
    ├── totalCalories = Σ (items.caloriesPer100g * grams / 100)
    ├── totalProtein = Σ (items.proteinPer100g * grams / 100)
    ├── totalFat = Σ (items.fatPer100g * grams / 100)
    └── totalCarbs = Σ (items.carbsPer100g * grams / 100)
    │
    ▼
与 DailyGoal 对比 → 进度条/环形图
```

---

## 7. 安全与隐私设计

### 7.1 API Key 保护

| 存储策略 | 说明 |
|----------|------|
| 密钥存储 | 全部通过 `KeychainStore` 写入 Keychain |
| 内存保护 | 使用 `NSString` 或临时 `Data`，及时清零 |
| 日志防护 | 在任何日志/错误消息中截断或掩码 Key |
| 传输保护 | 仅通过 HTTPS 请求头发送，不落盘 |

### 7.2 图片数据

- 原始照片**不持久化**到应用沙盒
- 仅保存**缩略图**（`@Attribute(.externalStorage)`）用于展示
- 图片仅在用户触发识别时上传到用户配置的 endpoint
- 无第三方图片处理服务介入

### 7.3 HealthKit 数据

- 请求最小必要权限（write: DietaryEnergy; read: ActiveEnergy, BodyMass）
- 用户可在设置中**随时开关** HealthKit 同步
- 授权被拒时优雅降级，不影响其他功能
- 数据写入策略：删除旧值 → 写入最新汇总值

### 7.4 隐私展示

设置页包含 **隐私说明** 页面（`PrivacyInfoView.swift`），向用户明确：

1. App 无自有后端，不收集数据
2. 图片仅发送到用户配置的 endpoint
3. API Key 仅存于 Keychain
4. HealthKit 数据可选
5. 第三方 endpoint 的数据处理责任在用户

---

## 8. 国际化方案

### 8.1 技术实现

- 使用 **String Catalog**（`Localizable.xcstrings`）：源语言为简体中文，含英文翻译
- 通过 `Bundle.main.preferredLocalizations` 实现运行时语言切换
- `AppLanguage.swift` 控制：用户可设置 `system`（跟随系统）/ `zh-Hans` / `en`

### 8.2 语言切换机制

```swift
enum AppLanguage: String {
    case system
    case chinese = "zh-Hans"
    case english = "en"
    
    func apply() {
        // 写入 UserDefaults 的 AppleLanguages key
        // 需要 App 重启生效
    }
}
```

### 8.3 LLM 输出语言

识别 prompt 中指示模型使用 App 当前界面语言输出：
- 中文界面 → 输出中文食物名与理由
- 英文界面 → 输出英文食物名与理由

---

## 9. 测试策略

### 9.1 单元测试

位置：`kcalshotTests/`

| 测试 | 覆盖内容 |
|------|----------|
| `BackupCodecTests` | JSON 编码/解码、合并/替换恢复模式 |
| `RecognitionAggregatorTests` | 多采样中位数聚合逻辑 |

### 9.2 测试覆盖目标

| 模块 | 覆盖范围 | 目标 |
|------|----------|------|
| 数据模型 | 计算属性 | ≥ 90% |
| 服务层 | 网络请求外的纯逻辑 | ≥ 85% |
| 工具类 | 图片压缩/数值计算 | ≥ 90% |

### 9.3 手动测试工具

- `tools/recognize_test.py`：Python 脚本，直接测试 LLM 识别的 JSON 响应
- `tools/test.sh`：Shell 辅助脚本

---

## 附录：关键设计决策记录

| 决策 | 方案 | 替代方案 | 理由 |
|------|------|----------|------|
| 营养存储格式 | 每 100g 密度 + 克数 | 存储绝对值 | 调整份量时只需改克数，密度数据可复用 |
| API Key 存储 | Keychain | UserDefaults + 加密 | 系统级安全存储，防明文泄露 |
| 图片压缩 | JPEG ≤1024px | 原图上传 | 降低 token 消耗和传输时间 |
| 模型配置 | 全局默认 + 模型覆盖 | 仅全局或仅逐个 | 兼顾通用性和灵活性 |
| needsReview | 客户端启发式 | 仅依赖 LLM 自报 | 更健壮，避免模型自报偏差 |
| 外部依赖 | 零依赖 | SPM/CocoaPods | 隐私、体积、维护成本最优 |
| 语言切换 | 重启生效 | 运行时切换（NSBundle） | 实现简单可靠 |
