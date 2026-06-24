#!/usr/bin/env python3
"""本地验证食物识别管线（prompt -> 请求 -> JSON 解析），与 App 的 RecognitionPrompt 对齐。

用法：
    export KCAL_BASE_URL="https://你的中转站/v1"
    export KCAL_API_KEY="sk-..."
    export KCAL_MODEL="gpt-4o"          # 一个支持视觉的模型 id
    python3 tools/recognize_test.py pic/IMG_4594.HEIC

不在任何地方保存 key；仅本次进程内使用。
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import urllib.request

SYSTEM_PROMPT = """你是营养分析助手。根据用户提供的食物照片，估算其营养信息。
只输出一个 JSON 对象，不要包含任何解释、前后缀或 Markdown 代码围栏。
JSON 结构如下：
{
  "items": [
    {"name": "食物名称", "calories": 数字(kcal), "protein": 数字(g), "fat": 数字(g), "carbs": 数字(g)}
  ],
  "healthScore": 1到10的整数(10最健康),
  "reason": "健康评分的简短理由",
  "recognitionConfidence": 0到1的小数(你对识别准确度的自评),
  "portionAssumed": true或false(份量是否为你的假设),
  "assumptions": "份量与估算的关键假设说明，例如：按一份约250g估算"
}
要求：
- 照片中每种可分辨的食物作为 items 中的一项。
- 数值为该项的估算值，营养为整道菜/整份的总量。
- 份量无法从照片确定时，按常见标准份量估算，将 portionAssumed 设为 true，并在 assumptions 说明假设。
- name、reason、assumptions 用「简体中文」输出。
- 只返回 JSON，不要其它任何文字。"""


def to_jpeg_data_uri(path: str) -> str:
    out = tempfile.mktemp(suffix=".jpg")
    subprocess.run(
        ["sips", "-s", "format", "jpeg", "-Z", "1024", path, "--out", out],
        check=True, capture_output=True,
    )
    with open(out, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    os.remove(out)
    return "data:image/jpeg;base64," + b64


def main():
    if len(sys.argv) < 2:
        print("用法: python3 tools/recognize_test.py <图片路径>")
        sys.exit(1)
    base_url = os.environ.get("KCAL_BASE_URL", "").rstrip("/")
    api_key = os.environ.get("KCAL_API_KEY", "")
    model = os.environ.get("KCAL_MODEL", "")
    if not (base_url and api_key and model):
        print("请先设置环境变量 KCAL_BASE_URL / KCAL_API_KEY / KCAL_MODEL")
        sys.exit(1)

    data_uri = to_jpeg_data_uri(sys.argv[1])
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": [
                {"type": "text", "text": "请分析这张食物照片，按要求只返回 JSON。"},
                {"type": "image_url", "image_url": {"url": data_uri}},
            ]},
        ],
        "max_tokens": 1200,
        "temperature": 0.2,
        "stream": False,
    }
    req = urllib.request.Request(
        base_url + "/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            status = resp.status
            ctype = resp.headers.get("Content-Type", "")
            raw = resp.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode(errors='replace')[:800]}")
        sys.exit(1)

    print(f"=== HTTP {status} · Content-Type: {ctype} ===")
    try:
        body = json.loads(raw)
    except json.JSONDecodeError:
        print("⚠️ 响应体不是标准 JSON，原始内容如下（前 1500 字）：")
        print(raw[:1500] if raw.strip() else "(空响应体)")
        sys.exit(1)

    content = body.get("choices", [{}])[0].get("message", {}).get("content", "")
    print("=== 模型原始返回 ===")
    print(content)
    print("=== JSON 解析 ===")
    try:
        start, end = content.index("{"), content.rindex("}")
        parsed = json.loads(content[start:end + 1])
        print("✅ 解析成功，items:", len(parsed.get("items", [])),
              "| healthScore:", parsed.get("healthScore"),
              "| portionAssumed:", parsed.get("portionAssumed"),
              "| confidence:", parsed.get("recognitionConfidence"))
    except Exception as exc:
        print("❌ 解析失败:", exc)


if __name__ == "__main__":
    main()
