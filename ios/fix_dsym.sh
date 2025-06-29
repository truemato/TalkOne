#!/bin/bash

# dSYM修正スクリプト for TestFlight upload
# Agora SDKのdSYM問題を解決するためのスクリプト

ARCHIVE_PATH="$1"
if [ -z "$ARCHIVE_PATH" ]; then
    echo "使用方法: $0 <Archive.xcarchive のパス>"
    exit 1
fi

echo "Archive path: $ARCHIVE_PATH"

# dSYMディレクトリのパス
DSYM_DIR="$ARCHIVE_PATH/dSYMs"

echo "dSYMディレクトリをチェック中..."
if [ ! -d "$DSYM_DIR" ]; then
    echo "dSYMディレクトリが見つかりません: $DSYM_DIR"
    exit 1
fi

# 問題のあるAgora関連のdSYMファイルを削除
AGORA_FRAMEWORKS=(
    "AgoraAiEchoCancellationExtension.framework.dSYM"
    "AgoraVideoSegmentationExtension.framework.dSYM"
    "AgoraContentInspectExtension.framework.dSYM"
    "AgoraRtcKit.framework.dSYM"
    "video_dec.framework.dSYM"
    "video_enc.framework.dSYM"
    "aosl.framework.dSYM"
)

echo "Agora関連のdSYMファイルを削除中..."
for framework in "${AGORA_FRAMEWORKS[@]}"; do
    dsym_path="$DSYM_DIR/$framework"
    if [ -d "$dsym_path" ]; then
        echo "削除中: $dsym_path"
        rm -rf "$dsym_path"
    else
        echo "見つかりません: $dsym_path"
    fi
done

# Runner.app.dSYMが存在することを確認
RUNNER_DSYM="$DSYM_DIR/Runner.app.dSYM"
if [ -d "$RUNNER_DSYM" ]; then
    echo "✓ Runner.app.dSYM が存在します"
else
    echo "⚠️  Runner.app.dSYM が見つかりません"
fi

echo "dSYM修正完了"
echo "残りのdSYMファイル:"
ls -la "$DSYM_DIR"

echo ""
echo "TestFlightアップロード時にXcodeから直接アーカイブをアップロードしてください。"