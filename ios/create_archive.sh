#!/bin/bash

# TestFlight用のアーカイブを正しく作成するスクリプト

echo "=== TestFlight Archive Creation Script ==="

# プロジェクトディレクトリに移動
cd "$(dirname "$0")/.."

# Flutterビルドをクリーン
echo "Cleaning Flutter build..."
flutter clean

# pub get実行
echo "Getting Flutter dependencies..."
flutter pub get

# iOSディレクトリに移動
cd ios

# Pod依存関係を更新
echo "Updating CocoaPods dependencies..."
pod install

# Xcodeビルド設定でdSYM生成を強制
echo "Forcing dSYM generation for Runner target..."

# プロジェクト設定ファイルに直接dSYM設定を追加
if ! grep -q "DEBUG_INFORMATION_FORMAT.*dwarf-with-dsym" Runner.xcodeproj/project.pbxproj; then
    echo "Adding dSYM generation settings to Xcode project..."
    
    # Release設定にdSYM生成を追加
    sed -i '' 's/DEBUG_INFORMATION_FORMAT = dwarf;/DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";/g' Runner.xcodeproj/project.pbxproj
fi

echo "=== Archive Creation Instructions ==="
echo "1. Open Xcode: open Runner.xcworkspace"
echo "2. Select 'Any iOS Device' as target"
echo "3. Product > Archive"
echo "4. After archive completion, run: ./fix_dsym.sh [archive_path]"
echo "5. Upload to TestFlight via Xcode Organizer"

# Xcodeワークスペースを開く
echo "Opening Xcode workspace..."
open Runner.xcworkspace

echo "Script completed. Please proceed with archive creation in Xcode."