import Foundation

/// 构造食物识别用的 system / user prompt。
enum RecognitionPrompt {
    /// 输出文本字段所用语言（跟随 App 界面语言，而非系统语言）。
    /// 目前界面为中文；将来接入真正的双语 UI 后，改为读取已解析的界面本地化语言。
    static var outputLanguageName: String {
        AppLanguage.current.outputName
    }

    static var system: String {
        """
        你是营养分析助手。根据用户提供的食物照片，估算其营养信息。
        只输出一个 JSON 对象，不要包含任何解释、前后缀或 Markdown 代码围栏。
        JSON 结构如下：
        {
          "items": [
            {
              "name": "食物名称",
              "grams": 数字(该食物的估计克数),
              "caloriesPer100g": 数字(每100克热量kcal),
              "proteinPer100g": 数字(每100克蛋白质g),
              "fatPer100g": 数字(每100克脂肪g),
              "carbsPer100g": 数字(每100克碳水g),
              "healthScore": 1到10的整数(这种食物本身的健康程度,10最健康)
            }
          ],
          "healthScore": 1到10的整数(整餐的综合健康程度,10最健康),
          "reason": "整餐健康评分的简短理由",
          "recognitionConfidence": 0到1的小数(你对识别准确度的自评),
          "portionAssumed": true或false(克数是否为你的假设),
          "assumptions": "份量估算的关键假设说明，例如：炒饭按一碗约250克估算"
        }
        要求：
        - 照片中每种可分辨的食物作为 items 中的一项，并为每一项单独给出 healthScore。
        - grams 是你对照片中该食物分量的估计克数；caloriesPer100g 等是该食物每 100 克的营养密度（与分量无关的常识值）。
        - 用户会核对/修改 grams，所以营养密度务必符合常识、分量务必尽量贴近照片。
        - 克数无法从照片确定时按常见标准份量估算，将 portionAssumed 设为 true，并在 assumptions 说明假设。
        - name、reason、assumptions 用「\(outputLanguageName)」输出。
        - 只返回 JSON，不要其它任何文字。
        """
    }

    static let userInstruction = "请分析这张食物照片，按要求只返回 JSON。"
}
