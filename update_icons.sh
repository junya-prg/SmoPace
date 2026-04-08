#!/bin/bash
ICON="/Users/hondajunya/.gemini/antigravity/brain/c4b138a5-f7ea-405e-a71a-9ddc8299452a/smopace_app_icon_1775655043231.png"

echo "ウィジェットアイコンを置換中..."
W="/Users/hondajunya/00_work/94_自作/SmoPace/SmokerWidget/Assets.xcassets/WidgetIcon.imageset"
cp "$ICON" "$W/AI_Smoker_1x_256x256.png" && sips -z 256 256 "$W/AI_Smoker_1x_256x256.png"
cp "$ICON" "$W/AI_Smoker_2x_512x512.png" && sips -z 512 512 "$W/AI_Smoker_2x_512x512.png"
cp "$ICON" "$W/AI_Smoker_3x_768x768.png" && sips -z 768 768 "$W/AI_Smoker_3x_768x768.png"

echo "スプラッシュ用アイコンを置換中..."
M="/Users/hondajunya/00_work/94_自作/SmoPace/Smoker/Assets.xcassets/AppIcon.imageset"
cp "$ICON" "$M/AppIcon.png" && sips -z 1024 1024 "$M/AppIcon.png"
cp "$ICON" "$M/image_2x_2048.png" && sips -z 2048 2048 "$M/image_2x_2048.png"
cp "$ICON" "$M/image_3x_3072.png" && sips -z 3072 3072 "$M/image_3x_3072.png"

echo "ウィジェット AppIconを置換中..."
A_W="/Users/hondajunya/00_work/94_自作/SmoPace/SmokerWidget/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
cp "$ICON" "$A_W" && sips -z 1024 1024 "$A_W"

echo "メイン AppIconを置換中..."
A_M="/Users/hondajunya/00_work/94_自作/SmoPace/Smoker/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
cp "$ICON" "$A_M" && sips -z 1024 1024 "$A_M"

echo "✅ すべてのアイコン画像の置換とリサイズが完了しました。"
