import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'notification_service.dart';

/// バージョン通知サービス
class VersionNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  static const String _lastVersionKey = 'last_notified_version';
  
  /// アプリ起動時にバージョンチェックと通知を実行
  Future<void> checkAndNotifyVersionUpdate() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // 現在のアプリバージョンを取得
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 最後に通知したバージョンを取得
      final prefs = await SharedPreferences.getInstance();
      final lastNotifiedVersion = prefs.getString(_lastVersionKey);
      
      // 初回起動またはバージョンアップデートがある場合
      if (lastNotifiedVersion == null || lastNotifiedVersion != currentVersion) {
        // バージョンアップデート通知を送信
        await _sendVersionUpdateNotification(currentVersion, lastNotifiedVersion);
        
        // 通知済みバージョンを保存
        await prefs.setString(_lastVersionKey, currentVersion);
      }
    } catch (e) {
      print('バージョン通知チェックエラー: $e');
    }
  }
  
  /// バージョンアップデート通知を送信
  Future<void> _sendVersionUpdateNotification(String newVersion, String? oldVersion) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      String title;
      String message;
      
      if (oldVersion == null) {
        // 初回起動
        title = 'TalkOneへようこそ！';
        message = 'バージョン $newVersion をインストールいただきありがとうございます。';
      } else {
        // アップデート
        title = 'アプリがアップデートされました';
        message = 'バージョン $oldVersion から $newVersion にアップデートされました。新機能をお楽しみください！';
      }
      
      // NotificationServiceのバージョン通知作成メソッドを使用
      await _notificationService.createVersionNotification(
        version: newVersion,
        title: title,
        message: message,
      );
      
      print('バージョン通知送信完了: $newVersion');
    } catch (e) {
      print('バージョン通知送信エラー: $e');
    }
  }

  /// 手動でバージョン通知を作成（デバッグ用）
  Future<bool> createManualVersionNotification() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      // 1.0.1バージョン通知を作成
      final success = await _notificationService.createVersionNotification(
        version: '1.0.1',
        title: 'Ver 1.0.1にアップデートしました',
        message: '1.0.1にアップデートしました。新機能をお楽しみください！',
      );
      
      if (success) {
        print('手動バージョン通知作成完了: 1.0.1');
      }
      return success;
    } catch (e) {
      print('手動バージョン通知作成エラー: $e');
      return false;
    }
  }
  
  /// アプリの最新バージョン情報を取得（将来の拡張用）
  Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('version_info')
          .get();
          
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('最新バージョン情報取得エラー: $e');
      return null;
    }
  }
}