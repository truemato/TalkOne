#!/bin/bash

# App Store Connect アップロード問題修正スクリプト
echo "🔧 App Store Connect アップロード問題を修正中..."

# 1. dSYM生成設定を無効化（Agora問題回避）
echo "📝 dSYM生成設定をdwarfに変更..."
# 既にproject.pbxprojで修正済み

# 2. CocoaPodsのdSYM設定更新
PODFILE_PATH="Podfile"

if [ -f "$PODFILE_PATH" ]; then
    echo "📁 Podfileにpost_install設定を追加..."
    
    # post_installブロックが存在するかチェック
    if ! grep -q "post_install" "$PODFILE_PATH"; then
        cat >> "$PODFILE_PATH" << 'EOF'

# dSYM問題回避のためのpost_install設定
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Agora SDKのdSYM生成を無効化
      if target.name.start_with?('Agora') || target.name == 'aosl' || target.name.start_with?('video_')
        config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
        config.build_settings['DWARF_DSYM_FOLDER_PATH'] = ''
        config.build_settings['DWARF_DSYM_FILE_NAME'] = ''
      end
      
      # iOS最小バージョン設定
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 12.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      end
    end
  end
end
EOF
        echo "✅ Podfileにpost_install設定を追加完了"
    else
        echo "⚠️  post_installブロックが既に存在します"
    fi
else
    echo "❌ Podfileが見つかりません"
fi

echo "🎯 App Store Connect アップロード問題修正完了"
echo ""
echo "📋 次のステップ:"
echo "1. pod install を実行"
echo "2. Xcodeでクリーンビルド (Shift+Cmd+K)"
echo "3. アーカイブ作成"
echo "4. App Store Connectにアップロード"