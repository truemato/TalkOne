// lib/utils/permission_util.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionUtil {
  static const _firstLaunchKey = 'is_first_launch_done';

  /// 初回ならマイク & 音声認識をリクエストして true を返す。
  /// 2 回目以降は何もしない。
  static Future<bool> handleFirstLaunchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final isDone = prefs.getBool(_firstLaunchKey) ?? false;
    print('PermissionUtil: 初回起動チェック - isDone: $isDone');
    
    if (isDone) {
      print('PermissionUtil: 既に権限リクエスト済み、スキップします');
      return true;
    }

    // ★ 必要な権限のみリクエスト（カメラ・Bluetoothは不要）
    print('PermissionUtil: 権限リクエストを開始します（マイク・音声認識のみ）');
    final statuses = await [
      Permission.microphone,
      Permission.speech,  // iOS音声認識用
    ].request();
    
    print('PermissionUtil: 権限リクエスト結果: $statuses');

    // いずれかが permanentlyDenied なら設定画面へ誘導してもよい
    final allGranted = statuses.values.every((st) => st.isGranted);

    // 1 回実行したらフラグを立てる（成功・失敗どちらでも）
    await prefs.setBool(_firstLaunchKey, true);
    return allGranted;
  }
  
  /// 権限の状態を確認（リクエストはしない）
  static Future<Map<Permission, PermissionStatus>> checkPermissionStatuses() async {
    final Map<Permission, PermissionStatus> statuses = {};
    statuses[Permission.microphone] = await Permission.microphone.status;
    statuses[Permission.speech] = await Permission.speech.status;
    return statuses;
  }
  
  /// 特定の権限が許可されているか確認
  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }
  
  /// 音声認識権限を確認・リクエスト
  static Future<bool> requestSpeechRecognitionPermission() async {
    final microphoneStatus = await Permission.microphone.status;
    final speechStatus = await Permission.speech.status;
    
    print('PermissionUtil: 音声認識権限確認 - マイク: $microphoneStatus, 音声認識: $speechStatus');
    
    if (!microphoneStatus.isGranted) {
      print('PermissionUtil: マイク権限をリクエストします');
      final newStatus = await Permission.microphone.request();
      if (!newStatus.isGranted) {
        print('PermissionUtil: マイク権限が拒否されました');
        return false;
      }
    }
    
    if (!speechStatus.isGranted) {
      print('PermissionUtil: 音声認識権限をリクエストします');
      final newStatus = await Permission.speech.request();
      if (!newStatus.isGranted) {
        print('PermissionUtil: 音声認識権限が拒否されました');
        return false;
      }
    }
    
    print('PermissionUtil: 音声認識権限OK');
    return true;
  }
  
  /// デバッグ用：初回起動フラグをリセット
  static Future<void> resetFirstLaunchFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
    print('PermissionUtil: 初回起動フラグをリセットしました');
  }
}