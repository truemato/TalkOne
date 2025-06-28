// lib/config/agora_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AgoraConfig {
  // Agora App ID (.envから取得 - セキュリティ強化)
  static String get appId => dotenv.env['AGORA_APP_ID'] ?? '';
  
  // App Certificate（本番環境では必須 - Cloud Runの環境変数で設定）
  static const String appCertificate = "YOUR_APP_CERTIFICATE_HERE";
  
  // 本番モードフラグ（トークン認証を使用するかどうか）
  static const bool useTokenAuthentication = false; // 開発環境ではfalse
  
  // トークンサーバーURL（Cloud Run）
  static const String tokenServerUrl = "https://agora-token-service-xxxxx.run.app";
  
  // テスト用のチャンネル設定
  static const String channelPrefix = "talkone_";
  
  // 音声品質設定
  static const int sampleRate = 16000;
  static const int bitrate = 32000;
  
  // 通話時間制限（秒）
  static const int callDurationSeconds = 180; // 3分
  
  // 一時的なトークン（開発環境でのみ使用）
  static const String? tempToken = null; // nullの場合はトークンなしで接続
  
  // Agoraプロジェクト設定
  static Map<String, dynamic> get rtcEngineConfig => {
    'appId': appId,
    'channelProfile': 0, // Communication (1対1通話に最適)
    'audioProfile': 0,   // Default (通話品質重視)
    'audioScenario': 0,  // Default (一般的な通話シナリオ)
  };
}