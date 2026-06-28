#!/usr/bin/env bash
# 一条命令跑单元测试。自动选模拟器：优先已启动的 iPhone，否则取第一个可用 iPhone。
# 用法：
#   tools/test.sh                 # 跑全部测试
#   tools/test.sh -only-testing:kcalshotTests/BackupCodecTests   # 透传额外参数
#   KCALSHOT_DEST='id=<UDID>' tools/test.sh   # 指定目标设备
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="${KCALSHOT_DEST:-}"
if [ -z "$DEST" ]; then
  UDID=$(xcrun simctl list devices booted | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)
  if [ -z "$UDID" ]; then
    UDID=$(xcrun simctl list devices available | grep -E 'iPhone' | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)
  fi
  if [ -z "$UDID" ]; then
    echo "找不到可用的 iPhone 模拟器，请先在 Xcode 装一个，或用 KCALSHOT_DEST 指定。" >&2
    exit 1
  fi
  DEST="id=$UDID"
fi

echo "==> xcodebuild test (destination: $DEST)"
exec xcodebuild test \
  -project kcalshot.xcodeproj \
  -scheme kcalshot \
  -destination "$DEST" \
  "$@"
