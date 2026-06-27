import Foundation

/// 构造食物识别用的 system / user prompt。
enum RecognitionPrompt {
    /// 输出文本字段所用语言，跟随 App 实际解析到的界面语言。
    static var outputLanguageName: String {
        AppLanguage.current.outputName
    }

    /// forText=false 为照片识别；true 为文字描述解析。
    static func system(forText: Bool) -> String {
        let source = forText ? "用户的文字描述" : "食物照片"
        let perItemNote = forText
            ? "描述中提到的每种食物作为 items 中的一项，并为每一项单独给出 healthScore。"
            : "照片中每种可分辨的食物作为 items 中的一项，并为每一项单独给出 healthScore。"
        let gramsNote = forText
            ? "grams 是该食物的估计克数：用户描述里若给了数量（如一根、一碗、一个），据此换算成克。"
            : "grams 是你对照片中该食物分量的估计克数；用户会核对/修改它。"
        let portionNote = forText
            ? "克数无法从描述确定时按常见标准份量估算，将 portionAssumed 设为 true，并在 assumptions 说明假设。"
            : "克数无法从照片确定时按常见标准份量估算，将 portionAssumed 设为 true，并在 assumptions 说明假设。"
        return """
        你是营养分析助手。根据\(source)，估算其营养信息。
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
              "healthScore": 1到10的整数(这种食物本身的健康程度,10最健康),
              "healthReason": "这种食物得到该健康评分的简短理由",
              "alternatives": [
                {
                  "name": "易混候选的食物名称",
                  "caloriesPer100g": 数字, "proteinPer100g": 数字,
                  "fatPer100g": 数字, "carbsPer100g": 数字,
                  "healthScore": 1到10的整数, "healthReason": "简短理由"
                }
              ]
            }
          ],
          "healthScore": 1到10的整数(整餐的综合健康程度,10最健康),
          "reason": "整餐健康评分的简短理由",
          "recognitionConfidence": 0到1的小数(你对识别准确度的自评),
          "portionAssumed": true或false(克数是否为你的假设),
          "assumptions": "份量估算的关键假设说明，例如：炒饭按一碗约250克估算"
        }
        要求：
        - \(perItemNote)
        - \(gramsNote)caloriesPer100g 等是该食物每 100 克的营养密度（与分量无关的常识值），务必符合常识。
        - \(portionNote)
        - 当某项仅凭外观无法与其它常见食物可靠区分时（例如白色饮品难分牛奶/豆浆/燕麦奶，相似的主食、酱料等），不要武断选定一个：name 填最可能的一种，并把其它最可能的 1~2 种连同各自营养放入该项 alternatives，同时调低 recognitionConfidence。能明确辨认的项 alternatives 必须为空数组 []。
        - name、reason、assumptions 与 alternatives 内的文本用「\(outputLanguageName)」输出。
        - 只返回 JSON，不要其它任何文字。
        """
    }

    static func photoUserInstruction(correction: String? = nil) -> String {
        var text = "请分析这张食物照片，按要求只返回 JSON。"
        if let correction, !correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "\n用户对上一次识别的更正（请优先采纳，据此修正对应食物）：\(correction)"
        }
        return text
    }

    static func textUserInstruction(_ description: String) -> String {
        "用户对这一餐的描述：\(description)\n请据此估算，按要求只返回 JSON。"
    }
}
