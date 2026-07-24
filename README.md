# KcalShot · 食刻

> 拍张照，就知道这顿吃了多少卡、够不够健康 —— 用你自己的 AI，数据由你掌控。
>
> Snap a photo, know your calories and nutrition — using your own AI, your data stays yours.

[![Platform](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange.svg)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 📖 简介 · Overview

**KcalShot（食刻）** 是一款 iOS 健康饮食管理 App。你只需拍一张食物照片，App 会调用你自有的 LLM（大语言模型）视觉能力，自动识别食物并估算热量、宏量营养素（蛋白质/脂肪/碳水）和健康评分（1–10 分）。

**核心差异：**
- 🔑 **BYO-API（自带 API）**：使用你自己的 API Key，无后端、不收集数据
- 🖼️ **多模型可切换**：随时换模型重新识别
- 🔒 **本地优先**：所有记录存储在本地（SwiftData），API Key 存入 Keychain
- 🌏 **中英双语**：界面跟随系统语言

**KcalShot** is a health & diet tracking iOS app. Take a photo of your meal, and the app uses **your own LLM API** to recognize foods and estimate calories, macronutrients (protein/fat/carbs), and a health score (1–10).

**Key differentiators:**
- 🔑 **BYO-API**: Use your own API key — no backend, no data collection
- 🖼️ **Multi-model**: Switch between models anytime for re-recognition
- 🔒 **Local-first**: All data stored on-device (SwiftData), API keys in Keychain
- 🌏 **Bilingual**: Chinese & English UI, follows system language

---

## ✨ 功能特性 · Features

| 功能 | 说明 |
|------|------|
| 📸 **拍照识别** | 相机拍摄或相册选取食物照片，LLM 自动识别并估算营养 |
| 🔄 **多模型切换** | 一个 API 端配置多个模型，识别不准一键切换重试 |
| ✏️ **结果修正** | AI 结果以可编辑表单呈现，支持修改、拆分、替换 |
| 📅 **三餐记录** | 早/午/晚/加餐分类记录，日历视图浏览历史 |
| 📊 **营养统计** | 每日热量与宏量营养素汇总，与目标对比展示 |
| 🎯 **TDEE 目标** | 根据 Mifflin-St Jeor 公式计算 BMR 与 TDEE，自动推荐 |
| 💧 **喝水记录** | 每日饮水追踪，快捷添加 |
| ⚖️ **体重追踪** | 体重记录与趋势查看 |
| ❤️ **HealthKit 同步** | 将摄入热量写入 Apple 健康（可选） |
| 💾 **数据备份** | JSON 备份/恢复（合并或替换模式），CSV 导出 |
| 🌏 **中英双语** | 界面语言跟随系统或手动切换 |

| Feature | Description |
|---------|-------------|
| 📸 **Photo Recognition** | Take or pick a food photo, LLM auto-recognizes and estimates nutrition |
| 🔄 **Multi-model** | Configure multiple models per API endpoint, one-tap re-recognize |
| ✏️ **Editable Results** | AI output as editable form — modify, split, or substitute items |
| 📅 **Meal Diary** | Breakfast/Lunch/Dinner/Snack logs with calendar view |
| 📊 **Nutrition Stats** | Daily calorie & macro summaries vs. goals |
| 🎯 **TDEE Goals** | Mifflin-St Jeor BMR/TDEE calculation with auto recommendations |
| 💧 **Water Tracking** | Daily water intake with quick-add presets |
| ⚖️ **Weight Logging** | Weight history with trend insights |
| ❤️ **HealthKit Sync** | Write dietary energy to Apple Health (optional) |
| 💾 **Data Backup** | JSON backup/restore (merge or replace), CSV export |
| 🌏 **Bilingual UI** | Chinese & English, follows system or manual toggle |

---

## 🚀 快速开始 · Quick Start

### 前置条件 · Prerequisites

- Xcode 16.2+
- iOS 17.0+ (physical device or simulator)
- An OpenAI-compatible API endpoint & key (e.g., OpenAI, Azure, local Ollama with vision model)

### 运行 · Run

```bash
# 克隆项目
git clone https://github.com/yourusername/kcalshot.git
cd kcalshot

# 用 Xcode 打开
open kcalshot.xcodeproj

# 选择目标设备后 Cmd+R 运行
```

### 首次使用 · First Use

1. 进入 **设置** → 配置 **全局 API Base URL** 和 **API Key**
2. 点击 **测试连接** 验证可用性
3. 添加一个或多个识别模型（需支持视觉）
4. 回到 **今天** 标签页，点击相机按钮开始识别！

---

## 🏗 技术架构 · Architecture

有关详细技术架构，请参见 [ARCHITECTURE.md](ARCHITECTURE.md)。

| 层级 | 技术选型 |
|------|----------|
| UI | SwiftUI |
| 数据持久化 | SwiftData |
| 架构模式 | MVVM（`@Observable` ViewModel） |
| 密钥存储 | Keychain |
| 网络 | URLSession + async/await |
| 外部依赖 | **无**（零第三方库） |
| 最低部署目标 | iOS 17.0 |

For a deep dive, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 📁 项目结构 · Project Structure

```
kcalshot/
├── kcalshotApp.swift           # App 入口 / Entry point
├── RootView.swift              # Tab 根视图 / Tab root
├── Localizable.xcstrings       # 国际化字符串 / String Catalog
├── Models/                     # SwiftData 数据模型 / Data models
│   ├── MealEntry.swift         # 三餐记录 / Meal record
│   ├── FoodItem.swift          # 食物项 / Food item (per-100g density)
│   ├── DailyGoal.swift         # TDEE 目标 / Daily goal
│   ├── APIModelConfig.swift    # LLM 模型配置 / LLM model config
│   ├── WeightEntry.swift       # 体重记录 / Weight entry
│   ├── WaterEntry.swift        # 喝水记录 / Water entry
│   ├── FavoriteFood.swift      # 收藏食物 / Favorite foods
│   └── TokenUsage.swift        # Token 用量 / Token usage
├── Services/                   # 核心服务 / Core services
│   ├── AppSettings.swift       # 全局设置 / Global settings
│   ├── KeychainStore.swift     # Keychain 封装 / Keychain wrapper
│   ├── LLMClient.swift         # OpenAI 兼容客户端 / API client
│   ├── HealthKitManager.swift  # HealthKit 管理 / HealthKit manager
│   ├── BackupCodec.swift       # 备份编解码 / Backup/restore
│   └── CSVExporter.swift       # CSV 导出 / CSV export
├── Features/                   # 功能模块 / Feature modules
│   ├── Capture/                # 拍照识别 / Photo recognition
│   ├── Today/                  # 今日概览 / Today's summary
│   ├── Diary/                  # 三餐记录 / Meal diary
│   ├── Insights/               # 统计洞察 / Statistics & charts
│   ├── Water/                  # 喝水记录 / Water tracking
│   └── Settings/               # 设置 / Settings
├── Shared/                     # 共享组件 / Shared components
│   ├── AppLanguage.swift       # 语言切换 / Language management
│   └── MealEntryRow.swift      # 通用餐食行 / Reusable meal row
└── Assets.xcassets/            # 资源文件 / Asset catalog
```

---

## 📚 文档 · Documentation

| 文档 | 说明 |
|------|------|
| [PRD.md](PRD.md) | 产品需求文档（中文） |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 技术架构文档 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 贡献指南 |

---

## 🧪 测试 · Testing

运行测试：

```bash
# Xcode 中 Product → Test (Cmd+U)
# 或命令行:
xcodebuild test -project kcalshot.xcodeproj -scheme kcalshot -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 🔒 隐私 · Privacy

- ✅ App **无自有后端**，不收集用户数据
- ✅ API Key 仅存入 **Keychain**，不落盘明文
- ✅ 原始照片不持久化，仅存缩略图用于记录展示
- ✅ 图片仅发送至**用户配置的 endpoint**，不由中间方转发
- ⚠️ 若使用第三方 API（如 OpenAI），图片将按其服务条款处理
- ✅ **HealthKit 数据可选开启**，用户可在设置中随时关闭

详情见设置中的 **隐私说明** 页面。

- ✅ **No backend** — the app has no server, no data collection
- ✅ API keys stored in **Keychain** only
- ✅ Original photos are not persisted; only thumbnails for display
- ✅ Images sent **only to the API endpoint you configure**
- ⚠️ Third-party endpoints (OpenAI, etc.) process images per their own terms
- ✅ **HealthKit is opt-in**, can be disabled anytime in settings

---

## 🔮 未来规划 · Roadmap

- 📈 周/月统计图表
- 🔔 用餐提醒通知
- 📱 iPad 适配
- 🏋️ 运动数据整合
- 📸 批量拍照识别

---

## 🤝 贡献 · Contributing

欢迎贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📄 许可 · License

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE)。

This project is open source under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">
  <sub>Built with ❤️ using SwiftUI & SwiftData</sub>
</div>
