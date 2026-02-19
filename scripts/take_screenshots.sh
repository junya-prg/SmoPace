#!/bin/bash

# App Store用スクリーンショット撮影スクリプト
# 使用方法: ./scripts/take_screenshots.sh

SIMCTL="/Applications/Xcode.app/Contents/Developer/usr/bin/simctl"
SCREENSHOT_DIR="$(pwd)/screenshots"
PROJECT_DIR="$(pwd)"

# スクリーンショット保存先を作成
mkdir -p "$SCREENSHOT_DIR"

echo "=== App Store用スクリーンショット撮影スクリプト ==="
echo ""
echo "必要なスクリーンショットサイズ:"
echo "  - iPhone 6.9インチ (iPhone 16 Pro Max): 1320 x 2868 px"
echo "  - iPhone 6.7インチ (iPhone 15 Pro Max): 1290 x 2796 px"  
echo "  - iPhone 6.5インチ (iPhone 14 Pro Max): 1284 x 2778 px"
echo "  - iPad Pro 13インチ: 2064 x 2752 px"
echo ""

# 撮影対象のシミュレータ（App Store要件に対応）
declare -A DEVICES
DEVICES["iPhone_6.9"]="iPhone 16 Pro Max"
DEVICES["iPhone_6.7"]="iPhone 15 Pro Max"
DEVICES["iPhone_6.5"]="iPhone 14 Pro Max"
DEVICES["iPad_13"]="iPad Pro (12.9-inch) (6th generation)"

echo "=== 手動撮影手順 ==="
echo ""
echo "1. Xcodeでプロジェクトを開く:"
echo "   open $PROJECT_DIR/Smoker.xcodeproj"
echo ""
echo "2. 各シミュレータでアプリを実行し、Cmd+S でスクリーンショットを保存:"
echo ""

for key in "${!DEVICES[@]}"; do
    device="${DEVICES[$key]}"
    echo "   [$key] $device"
done

echo ""
echo "3. スクリーンショットは ~/Desktop に保存されます"
echo "   保存後、$SCREENSHOT_DIR に移動してください"
echo ""
echo "=== 撮影すべき画面 ==="
echo ""
echo "App Storeでは最大10枚のスクリーンショットをアップロードできます。"
echo "推奨する撮影画面:"
echo "  1. メイン画面（喫煙記録ボタン）"
echo "  2. 統計画面（日別表示）"
echo "  3. 統計画面（週別/月別表示）"
echo "  4. 設定画面"
echo "  5. ウィジェット表示"
echo ""
echo "=== シミュレータの起動コマンド ==="
echo ""

for key in "${!DEVICES[@]}"; do
    device="${DEVICES[$key]}"
    # デバイスUUIDを取得
    uuid=$($SIMCTL list devices available | grep "$device" | head -1 | grep -oE '[A-F0-9-]{36}')
    if [ -n "$uuid" ]; then
        echo "# $key ($device)"
        echo "$SIMCTL boot $uuid"
        echo "open -a Simulator"
        echo ""
    fi
done

echo "=== スクリーンショット撮影コマンド ==="
echo ""
echo "シミュレータ起動後、以下のコマンドで撮影できます:"
echo ""
echo "# 起動中のシミュレータのスクリーンショットを撮影"
echo "$SIMCTL io booted screenshot $SCREENSHOT_DIR/screenshot_\$(date +%Y%m%d_%H%M%S).png"
echo ""
