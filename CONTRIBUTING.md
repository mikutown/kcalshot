# 贡献指南 · Contributing Guide

感谢你对 KcalShot 的关注！我们欢迎各种形式的贡献。

Thanks for your interest in KcalShot! All kinds of contributions are welcome.

---

## 🐛 报告 Bug · Reporting Bugs

1. 在 [Issues](https://github.com/yourusername/kcalshot/issues) 中搜索是否已有相同报告
2. 如没有，创建新 Issue，包含：
   - 设备型号与 iOS 版本
   - 复现步骤（越详细越好）
   - 预期行为与实际行为
   - 如有崩溃日志，请附上

---

## 💡 功能建议 · Feature Requests

欢迎在 Issues 中提建议，请说明：
- 要解决什么问题
- 预期的行为
- 是否愿意参与实现

---

## 🛠️ 代码贡献 · Code Contributions

### 环境要求

- Xcode 16.2+
- iOS 17.0+
- Swift 5

### 开发流程

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feat/your-feature`
3. 遵循项目编码规范
4. 编写/更新测试
5. 确保所有测试通过
6. 提交 PR

### 编码规范

- 遵循 [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- 使用 `@Observable` 而非 `ObservableObject`（iOS 17+）
- 优先使用 `async/await` 而非回调闭包
- 文件命名：`FeatureName.swift`（View/ViewModel），`ServiceName.swift`（Services）
- ViewModel 放在对应 Feature 目录下
- 国际化字符串添加到 `Localizable.xcstrings`
- 保持零第三方依赖原则

### Commit 规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>: <简短描述>

<可选的详细描述>
```

- `feat:` 新功能
- `fix:` Bug 修复
- `refactor:` 重构
- `docs:` 文档变更
- `test:` 测试变更
- `chore:` 构建/工具变更

---

## 📚 文档贡献 · Documentation

文档文件（`.md`）使用中英双语撰写。中文为主、英文为辅。

---

## Code of Conduct

请保持友善、尊重的沟通方式。本项目遵循标准的开源社区行为准则。

Please be respectful and constructive. This project follows standard open source community guidelines.

---

<div align="right">
  <sub>Built with ❤️ using SwiftUI & SwiftData</sub>
</div>
