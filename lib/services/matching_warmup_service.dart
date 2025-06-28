import 'dart:convert';
import 'package:http/http.dart' as http;

/// マッチング時のVOICEVOX Engineウォームアップサービス
/// 
/// コールドスタート対策として、マッチングが成立した時点で
/// VOICEVOX Engineの複数プロセスを事前起動します。
class MatchingWarmupService {
  static const String _ttsApiHost = 'https://voicevox-tts-api-198779252752.asia-northeast1.run.app';
  static const int _warmupEngineCount = 2;
  
  /// マッチング成立時のエンジンウォームアップ
  Future<bool> warmupEnginesOnMatching() async {
    try {
      print('マッチング成立: VOICEVOX Engineウォームアップ開始...');
      
      final response = await http.post(
        Uri.parse('$_ttsApiHost/warmup'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('ウォームアップ成功: ${responseData['message']}');
        return true;
      } else {
        print('ウォームアップ失敗: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('ウォームアップエラー: $e');
      return false;
    }
  }
  
  /// TTS APIの健康状態チェック
  Future<bool> checkTTSAPIHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_ttsApiHost/health'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final healthData = json.decode(response.body);
        print('TTS API状態: ${healthData['status']}');
        print('エンジンウォーム状態: ${healthData['engines_warmed']}');
        return healthData['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('TTS APIヘルスチェックエラー: $e');
      return false;
    }
  }
  
  /// マッチング待機中の予備ウォームアップ
  Future<void> preWarmupOnLowLoad() async {
    try {
      // 軽量なヘルスチェック
      final isHealthy = await checkTTSAPIHealth();
      if (!isHealthy) {
        print('TTS APIが不健全、予備ウォームアップを実行');
        await warmupEnginesOnMatching();
      }
    } catch (e) {
      print('予備ウォームアップエラー: $e');
    }
  }
}