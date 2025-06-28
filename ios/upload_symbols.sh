#!/bin/bash

# Agora SDK用dSYMアップロードスクリプト
# App Store Connect のシンボルアップロード問題を解決

echo "🔧 Agora SDK dSYM問題の回避スクリプト実行中..."

# CocoaPods由来のフレームワークのdSYM生成
FRAMEWORKS_PATH="${BUILT_PRODUCTS_DIR}"
DSYM_PATH="${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"

# Agoraフレームワーク一覧
AGORA_FRAMEWORKS=(
    "AgoraAiEchoCancellationExtension"
    "AgoraAiEchoCancellationLLExtension"
    "AgoraAiNoiseSuppressionExtension"
    "AgoraAiNoiseSuppressionLLExtension"
    "AgoraAudioBeautyExtension"
    "AgoraClearVisionExtension"
    "AgoraContentInspectExtension"
    "AgoraFaceCaptureExtension"
    "AgoraFaceDetectionExtension"
    "AgoraLipSyncExtension"
    "AgoraReplayKitExtension"
    "AgoraRtcKit"
    "AgoraRtcWrapper"
    "AgoraSoundTouch"
    "AgoraSpatialAudioExtension"
    "AgoraVideoAv1DecoderExtension"
    "AgoraVideoAv1EncoderExtension"
    "AgoraVideoDecoderExtension"
    "AgoraVideoEncoderExtension"
    "AgoraVideoQualityAnalyzerExtension"
    "AgoraVideoSegmentationExtension"
    "Agorafdkaac"
    "Agoraffmpeg"
    "aosl"
    "video_dec"
    "video_enc"
)

# 各フレームワークのdSYM生成を試行
for framework in "${AGORA_FRAMEWORKS[@]}"; do
    framework_path="${FRAMEWORKS_PATH}/${framework}.framework"
    if [ -d "$framework_path" ]; then
        echo "✅ ${framework}.framework found, creating dSYM placeholder..."
        
        # dSYMフォルダ作成
        dsym_framework_path="${DSYM_PATH}/Contents/Resources/DWARF/${framework}"
        mkdir -p "$(dirname "$dsym_framework_path")"
        
        # プレースホルダーdSYMファイル作成（空のDWARFファイル）
        touch "$dsym_framework_path"
        echo "📁 Created placeholder dSYM: $dsym_framework_path"
    else
        echo "⚠️  ${framework}.framework not found in ${FRAMEWORKS_PATH}"
    fi
done

echo "🎯 Agora SDK dSYM処理完了"