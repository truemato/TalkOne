// lib/config/app_config.dart
class AppConfig {
  // 開発時設定
  static const bool useAgoraSimulation = false; // true: シミュレーション使用, false: 実際のAgora使用
  
  // その他の設定
  static const bool enableDebugLogs = true;
  static const Duration callDuration = Duration(minutes: 3);
}