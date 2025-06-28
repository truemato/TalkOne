#!/bin/bash

# gRPC-Core PrivacyInfo.xcprivacy修正スクリプト
echo "🔧 gRPC-Core PrivacyInfo.xcprivacy問題を修正中..."

GRPC_PRIVACY_PATH="Pods/gRPC-Core/src/objective-c/PrivacyInfo.xcprivacy"

if [ ! -f "$GRPC_PRIVACY_PATH" ]; then
    echo "📁 gRPC-Core PrivacyInfo.xcprivacyファイルを作成中..."
    
    # ディレクトリ作成
    mkdir -p "$(dirname "$GRPC_PRIVACY_PATH")"
    
    # プライバシーファイル作成
    cat > "$GRPC_PRIVACY_PATH" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryNetworking</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>NSPrivacyAccessedAPIReasonNetworkOperation</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
    </array>
    <key>NSPrivacyTrackingDomains</key>
    <array>
    </array>
</dict>
</plist>
EOF
    
    echo "✅ gRPC-Core PrivacyInfo.xcprivacy作成完了"
else
    echo "✅ gRPC-Core PrivacyInfo.xcprivacyは既に存在します"
fi

echo "🎯 gRPC-Core修正完了"